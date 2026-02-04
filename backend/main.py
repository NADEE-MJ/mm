"""FastAPI main application for movie recommendations with user authentication."""

import json
import logging
import time
from datetime import timedelta
from pathlib import Path
from typing import List, Optional

from auth import (
    ACCESS_TOKEN_EXPIRE_DAYS,
    Token,
    UserCreate,
    UserLogin,
    UserResponse,
    authenticate_user,
    create_access_token,
    create_user,
    get_current_user,
    get_required_user,
    get_user_by_email,
    get_user_by_username,
)
from database import engine, get_db
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from models import (
    Base,
    CustomList,
    Movie,
    MovieStatus,
    Person,
    Recommendation,
    User,
    WatchHistory,
)
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create tables (in case migrations weren't run)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Movie Recommendations API", version="2.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://localhost:5174",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic models for request/response
class RecommendationCreate(BaseModel):
    person: str
    date_recommended: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


class RecommendationResponse(BaseModel):
    id: int
    imdb_id: str
    person: str
    date_recommended: float

    model_config = ConfigDict(from_attributes=True)


class WatchHistoryCreate(BaseModel):
    date_watched: float
    my_rating: float = Field(..., ge=1.0, le=10.0)

    model_config = ConfigDict(from_attributes=True)


class WatchHistoryResponse(BaseModel):
    imdb_id: str
    date_watched: float
    my_rating: float

    model_config = ConfigDict(from_attributes=True)


class MovieStatusUpdate(BaseModel):
    status: str = Field(..., pattern="^(toWatch|watched|deleted|custom)$")
    custom_list_id: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class MovieCreate(BaseModel):
    imdb_id: str
    tmdb_data: Optional[dict] = None
    omdb_data: Optional[dict] = None

    model_config = ConfigDict(from_attributes=True)


class MovieResponse(BaseModel):
    imdb_id: str
    tmdb_data: Optional[dict] = None
    omdb_data: Optional[dict] = None
    last_modified: float
    status: Optional[str] = None
    recommendations: List[RecommendationResponse] = []
    watch_history: Optional[WatchHistoryResponse] = None

    model_config = ConfigDict(from_attributes=True)


class PersonCreate(BaseModel):
    name: str
    is_trusted: bool = False
    is_default: bool = False

    model_config = ConfigDict(from_attributes=True)


class PersonResponse(BaseModel):
    name: str
    is_trusted: bool
    is_default: bool = False

    model_config = ConfigDict(from_attributes=True)


class PersonUpdate(BaseModel):
    is_trusted: bool

    model_config = ConfigDict(from_attributes=True)


class CustomListCreate(BaseModel):
    name: str
    color: str = "#0a84ff"
    icon: str = "list"
    position: int = 0

    model_config = ConfigDict(from_attributes=True)


class CustomListUpdate(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    position: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class CustomListResponse(BaseModel):
    id: str
    name: str
    color: str
    icon: str
    position: int
    created_at: float

    model_config = ConfigDict(from_attributes=True)


class PersonStatsResponse(BaseModel):
    name: str
    is_trusted: bool
    is_default: bool
    total_movies: int
    watched_movies: int
    average_rating: Optional[float] = None
    movies: List[MovieResponse] = []

    model_config = ConfigDict(from_attributes=True)


class SyncAction(BaseModel):
    action: str
    data: dict
    timestamp: float

    model_config = ConfigDict(from_attributes=True)


class SyncResponse(BaseModel):
    success: bool
    last_modified: Optional[float] = None
    error: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


# Helper functions
def get_or_create_movie(
    db: Session,
    user_id: str,
    imdb_id: str,
    tmdb_data: dict = None,
    omdb_data: dict = None,
) -> Movie:
    """Get existing movie or create new one for a user."""
    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == imdb_id, Movie.user_id == user_id)
        .first()
    )
    if not movie:
        movie = Movie(
            imdb_id=imdb_id,
            user_id=user_id,
            tmdb_data=json.dumps(tmdb_data) if tmdb_data else None,
            omdb_data=json.dumps(omdb_data) if omdb_data else None,
        )
        db.add(movie)
        # Create default status
        status = MovieStatus(imdb_id=imdb_id, user_id=user_id, status="toWatch")
        db.add(status)
        db.commit()
        db.refresh(movie)
    return movie


# ============== Auth Endpoints ==============


@app.post(
    "/api/auth/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(user: UserCreate, db: Session = Depends(get_db)):
    """Register a new user."""
    # Check if email already exists
    if get_user_by_email(db, user.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered"
        )
    # Check if username already exists
    if get_user_by_username(db, user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Username already taken"
        )

    db_user = create_user(db, user)
    return db_user


@app.post("/api/auth/login", response_model=Token)
async def login(user: UserLogin, db: Session = Depends(get_db)):
    """Login and get access token."""
    db_user = authenticate_user(db, user.email, user.password)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(
        data={"sub": db_user.id}, expires_delta=timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.get("/api/auth/me", response_model=UserResponse)
async def get_current_user_info(user: User = Depends(get_required_user)):
    """Get current user info."""
    return user


# ============== API Endpoints ==============


@app.get("/api/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": time.time()}


@app.post(
    "/api/movies/{imdb_id}/recommendations",
    response_model=RecommendationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_recommendation(
    imdb_id: str,
    recommendation: RecommendationCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Add a recommendation for a movie."""
    movie = get_or_create_movie(db, user.id, imdb_id)

    # Check if recommendation already exists
    existing = (
        db.query(Recommendation)
        .filter(
            Recommendation.imdb_id == imdb_id,
            Recommendation.user_id == user.id,
            Recommendation.person == recommendation.person,
        )
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Recommendation from this person already exists",
        )

    # Create recommendation
    db_recommendation = Recommendation(
        imdb_id=imdb_id,
        user_id=user.id,
        person=recommendation.person,
        date_recommended=recommendation.date_recommended or time.time(),
    )
    db.add(db_recommendation)

    # Ensure person exists for this user
    person = (
        db.query(Person)
        .filter(Person.name == recommendation.person, Person.user_id == user.id)
        .first()
    )
    if not person:
        person = Person(name=recommendation.person, user_id=user.id, is_trusted=False)
        db.add(person)

    movie.last_modified = time.time()
    db.commit()
    db.refresh(db_recommendation)

    return db_recommendation


@app.delete(
    "/api/movies/{imdb_id}/recommendations/{person}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_recommendation(
    imdb_id: str,
    person: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Remove a recommendation."""
    recommendation = (
        db.query(Recommendation)
        .filter(
            Recommendation.imdb_id == imdb_id,
            Recommendation.user_id == user.id,
            Recommendation.person == person,
        )
        .first()
    )

    if not recommendation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Recommendation not found"
        )

    db.delete(recommendation)

    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == imdb_id, Movie.user_id == user.id)
        .first()
    )
    if movie:
        movie.last_modified = time.time()

    db.commit()
    return None


@app.put("/api/movies/{imdb_id}/watch", response_model=WatchHistoryResponse)
async def mark_watched(
    imdb_id: str,
    watch_data: WatchHistoryCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Mark a movie as watched with rating."""
    movie = get_or_create_movie(db, user.id, imdb_id)

    existing = (
        db.query(WatchHistory)
        .filter(WatchHistory.imdb_id == imdb_id, WatchHistory.user_id == user.id)
        .first()
    )

    if existing:
        existing.date_watched = watch_data.date_watched
        existing.my_rating = watch_data.my_rating
        db_watch = existing
    else:
        db_watch = WatchHistory(
            imdb_id=imdb_id,
            user_id=user.id,
            date_watched=watch_data.date_watched,
            my_rating=watch_data.my_rating,
        )
        db.add(db_watch)

    # Update movie status to watched
    movie_status = (
        db.query(MovieStatus)
        .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
        .first()
    )
    if movie_status:
        movie_status.status = "watched"
    else:
        movie_status = MovieStatus(imdb_id=imdb_id, user_id=user.id, status="watched")
        db.add(movie_status)

    movie.last_modified = time.time()
    db.commit()
    db.refresh(db_watch)

    return db_watch


@app.put("/api/movies/{imdb_id}/status", response_model=dict)
async def update_movie_status(
    imdb_id: str,
    status_update: MovieStatusUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Update movie status."""
    movie = get_or_create_movie(db, user.id, imdb_id)

    movie_status = (
        db.query(MovieStatus)
        .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
        .first()
    )
    if movie_status:
        movie_status.status = status_update.status
        movie_status.custom_list_id = (
            status_update.custom_list_id if status_update.status == "custom" else None
        )
    else:
        movie_status = MovieStatus(
            imdb_id=imdb_id,
            user_id=user.id,
            status=status_update.status,
            custom_list_id=status_update.custom_list_id
            if status_update.status == "custom"
            else None,
        )
        db.add(movie_status)

    movie.last_modified = time.time()
    db.commit()

    return {
        "imdb_id": imdb_id,
        "status": status_update.status,
        "custom_list_id": movie_status.custom_list_id,
        "last_modified": movie.last_modified,
    }


@app.get("/api/movies/{imdb_id}", response_model=MovieResponse)
async def get_movie(
    imdb_id: str, user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get movie details with recommendations and watch history."""
    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == imdb_id, Movie.user_id == user.id)
        .first()
    )

    if not movie:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found"
        )

    response = {
        "imdb_id": movie.imdb_id,
        "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
        "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
        "last_modified": movie.last_modified,
        "status": movie.status.status if movie.status else None,
        "recommendations": movie.recommendations,
        "watch_history": movie.watch_history,
    }

    return response


@app.get("/api/movies", response_model=List[MovieResponse])
async def get_all_movies(
    user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get all movies for the current user."""
    movies = db.query(Movie).filter(Movie.user_id == user.id).all()

    results = []
    for movie in movies:
        results.append(
            {
                "imdb_id": movie.imdb_id,
                "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
                "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
                "last_modified": movie.last_modified,
                "status": movie.status.status if movie.status else None,
                "recommendations": movie.recommendations,
                "watch_history": movie.watch_history,
            }
        )

    return results


@app.get("/api/sync")
async def sync_get_changes(
    since: float = 0,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get all changes since timestamp for sync."""
    movies = (
        db.query(Movie)
        .filter(Movie.user_id == user.id, Movie.last_modified > since)
        .all()
    )

    results = []
    for movie in movies:
        results.append(
            {
                "imdb_id": movie.imdb_id,
                "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
                "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
                "last_modified": movie.last_modified,
                "status": movie.status.status if movie.status else None,
                "recommendations": [
                    {
                        "id": r.id,
                        "imdb_id": r.imdb_id,
                        "person": r.person,
                        "date_recommended": r.date_recommended,
                    }
                    for r in movie.recommendations
                ],
                "watch_history": {
                    "imdb_id": movie.watch_history.imdb_id,
                    "date_watched": movie.watch_history.date_watched,
                    "my_rating": movie.watch_history.my_rating,
                }
                if movie.watch_history
                else None,
            }
        )

    # Also get people
    people = db.query(Person).filter(Person.user_id == user.id).all()
    people_list = [{"name": p.name, "is_trusted": p.is_trusted} for p in people]

    return {"movies": results, "people": people_list, "timestamp": time.time()}


@app.post("/api/sync", response_model=SyncResponse)
async def sync_process_action(
    action: SyncAction,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Process a queued sync action."""
    try:
        action_type = action.action
        data = action.data

        if action_type == "addRecommendation":
            imdb_id = data.get("imdb_id")
            person = data.get("person")
            movie = get_or_create_movie(
                db, user.id, imdb_id, data.get("tmdb_data"), data.get("omdb_data")
            )

            existing = (
                db.query(Recommendation)
                .filter(
                    Recommendation.imdb_id == imdb_id,
                    Recommendation.user_id == user.id,
                    Recommendation.person == person,
                )
                .first()
            )

            if not existing:
                db_recommendation = Recommendation(
                    imdb_id=imdb_id,
                    user_id=user.id,
                    person=person,
                    date_recommended=data.get("date_recommended", time.time()),
                )
                db.add(db_recommendation)

                person_obj = (
                    db.query(Person)
                    .filter(Person.name == person, Person.user_id == user.id)
                    .first()
                )
                if not person_obj:
                    person_obj = Person(name=person, user_id=user.id, is_trusted=False)
                    db.add(person_obj)

            movie.last_modified = time.time()
            db.commit()

            return SyncResponse(success=True, last_modified=movie.last_modified)

        elif action_type == "markWatched":
            imdb_id = data.get("imdb_id")
            movie = get_or_create_movie(db, user.id, imdb_id)

            existing = (
                db.query(WatchHistory)
                .filter(
                    WatchHistory.imdb_id == imdb_id, WatchHistory.user_id == user.id
                )
                .first()
            )
            if existing:
                existing.date_watched = data.get("date_watched")
                existing.my_rating = data.get("my_rating")
            else:
                db_watch = WatchHistory(
                    imdb_id=imdb_id,
                    user_id=user.id,
                    date_watched=data.get("date_watched"),
                    my_rating=data.get("my_rating"),
                )
                db.add(db_watch)

            movie_status = (
                db.query(MovieStatus)
                .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
                .first()
            )
            if movie_status:
                movie_status.status = "watched"
            else:
                movie_status = MovieStatus(
                    imdb_id=imdb_id, user_id=user.id, status="watched"
                )
                db.add(movie_status)

            movie.last_modified = time.time()
            db.commit()

            return SyncResponse(success=True, last_modified=movie.last_modified)

        elif action_type == "updateStatus":
            imdb_id = data.get("imdb_id")
            new_status = data.get("status")
            movie = get_or_create_movie(db, user.id, imdb_id)

            movie_status = (
                db.query(MovieStatus)
                .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
                .first()
            )
            if movie_status:
                movie_status.status = new_status
            else:
                movie_status = MovieStatus(
                    imdb_id=imdb_id, user_id=user.id, status=new_status
                )
                db.add(movie_status)

            movie.last_modified = time.time()
            db.commit()

            return SyncResponse(success=True, last_modified=movie.last_modified)

        elif action_type == "addPerson":
            name = data.get("name")
            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if not person:
                person = Person(
                    name=name, user_id=user.id, is_trusted=data.get("is_trusted", False)
                )
                db.add(person)
                db.commit()

            return SyncResponse(success=True, last_modified=time.time())

        elif action_type == "updatePersonTrust":
            name = data.get("name")
            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if person:
                person.is_trusted = data.get("is_trusted")
                db.commit()

            return SyncResponse(success=True, last_modified=time.time())

        else:
            return SyncResponse(
                success=False, error=f"Unknown action type: {action_type}"
            )

    except Exception as e:
        db.rollback()
        logger.error("Sync action failed: %s", str(e))
        return SyncResponse(success=False, error=str(e))


@app.get("/api/people", response_model=List[PersonResponse])
async def get_people(
    user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get all people for the current user."""
    people = db.query(Person).filter(Person.user_id == user.id).all()
    return people


@app.post(
    "/api/people", response_model=PersonResponse, status_code=status.HTTP_201_CREATED
)
async def add_person(
    person: PersonCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Add a new person."""
    existing = (
        db.query(Person)
        .filter(Person.name == person.name, Person.user_id == user.id)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Person already exists"
        )

    db_person = Person(name=person.name, user_id=user.id, is_trusted=person.is_trusted)
    db.add(db_person)
    db.commit()
    db.refresh(db_person)

    return db_person


@app.put("/api/people/{name}", response_model=PersonResponse)
async def update_person(
    name: str,
    person_update: PersonUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Update person's trusted status."""
    person = (
        db.query(Person).filter(Person.name == name, Person.user_id == user.id).first()
    )
    if not person:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Person not found"
        )

    person.is_trusted = person_update.is_trusted
    db.commit()
    db.refresh(person)

    return person


@app.get("/api/people/{name}/stats", response_model=PersonStatsResponse)
async def get_person_stats(
    name: str, user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get stats for a specific person including their movies."""
    person = (
        db.query(Person).filter(Person.name == name, Person.user_id == user.id).first()
    )
    if not person:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Person not found"
        )

    # Get all recommendations by this person
    recommendations = (
        db.query(Recommendation)
        .filter(Recommendation.person == name, Recommendation.user_id == user.id)
        .all()
    )

    movie_imdb_ids = [r.imdb_id for r in recommendations]

    # Get all movies recommended by this person
    movies = (
        db.query(Movie)
        .filter(Movie.imdb_id.in_(movie_imdb_ids), Movie.user_id == user.id)
        .all()
        if movie_imdb_ids
        else []
    )

    # Calculate stats
    total_movies = len(movies)
    watched_movies = 0
    total_rating = 0
    rated_count = 0

    movie_responses = []
    for movie in movies:
        status = movie.status.status if movie.status else None
        if status == "watched":
            watched_movies += 1

        if movie.watch_history:
            total_rating += movie.watch_history.my_rating
            rated_count += 1

        movie_responses.append(
            {
                "imdb_id": movie.imdb_id,
                "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
                "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
                "last_modified": movie.last_modified,
                "status": status,
                "recommendations": movie.recommendations,
                "watch_history": movie.watch_history,
            }
        )

    average_rating = round(total_rating / rated_count, 1) if rated_count > 0 else None

    return {
        "name": person.name,
        "is_trusted": person.is_trusted,
        "is_default": person.is_default,
        "total_movies": total_movies,
        "watched_movies": watched_movies,
        "average_rating": average_rating,
        "movies": movie_responses,
    }


# ============== Custom Lists Endpoints ==============


@app.get("/api/lists", response_model=List[CustomListResponse])
async def get_custom_lists(
    user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get all custom lists for the current user."""
    lists = (
        db.query(CustomList)
        .filter(CustomList.user_id == user.id)
        .order_by(CustomList.position)
        .all()
    )
    return lists


@app.post(
    "/api/lists", response_model=CustomListResponse, status_code=status.HTTP_201_CREATED
)
async def create_custom_list(
    list_data: CustomListCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Create a new custom list."""
    import uuid

    db_list = CustomList(
        id=str(uuid.uuid4()),
        user_id=user.id,
        name=list_data.name,
        color=list_data.color,
        icon=list_data.icon,
        position=list_data.position,
    )
    db.add(db_list)
    db.commit()
    db.refresh(db_list)
    return db_list


@app.get("/api/lists/{list_id}", response_model=CustomListResponse)
async def get_custom_list(
    list_id: str, user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get a specific custom list."""
    db_list = (
        db.query(CustomList)
        .filter(CustomList.id == list_id, CustomList.user_id == user.id)
        .first()
    )
    if not db_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="List not found"
        )
    return db_list


@app.put("/api/lists/{list_id}", response_model=CustomListResponse)
async def update_custom_list(
    list_id: str,
    list_update: CustomListUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Update a custom list."""
    db_list = (
        db.query(CustomList)
        .filter(CustomList.id == list_id, CustomList.user_id == user.id)
        .first()
    )
    if not db_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="List not found"
        )

    if list_update.name is not None:
        db_list.name = list_update.name
    if list_update.color is not None:
        db_list.color = list_update.color
    if list_update.icon is not None:
        db_list.icon = list_update.icon
    if list_update.position is not None:
        db_list.position = list_update.position

    db.commit()
    db.refresh(db_list)
    return db_list


@app.delete("/api/lists/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_custom_list(
    list_id: str, user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Delete a custom list and move its movies back to toWatch."""
    db_list = (
        db.query(CustomList)
        .filter(CustomList.id == list_id, CustomList.user_id == user.id)
        .first()
    )
    if not db_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="List not found"
        )

    # Move movies back to toWatch
    db.query(MovieStatus).filter(
        MovieStatus.custom_list_id == list_id, MovieStatus.user_id == user.id
    ).update({"status": "toWatch", "custom_list_id": None})

    db.delete(db_list)
    db.commit()
    return None


@app.get("/api/lists/{list_id}/movies", response_model=List[MovieResponse])
async def get_custom_list_movies(
    list_id: str, user: User = Depends(get_required_user), db: Session = Depends(get_db)
):
    """Get all movies in a custom list."""
    # Verify list exists
    db_list = (
        db.query(CustomList)
        .filter(CustomList.id == list_id, CustomList.user_id == user.id)
        .first()
    )
    if not db_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="List not found"
        )

    # Get movie statuses in this list
    statuses = (
        db.query(MovieStatus)
        .filter(MovieStatus.custom_list_id == list_id, MovieStatus.user_id == user.id)
        .all()
    )

    imdb_ids = [s.imdb_id for s in statuses]
    movies = (
        db.query(Movie)
        .filter(Movie.imdb_id.in_(imdb_ids), Movie.user_id == user.id)
        .all()
        if imdb_ids
        else []
    )

    results = []
    for movie in movies:
        results.append(
            {
                "imdb_id": movie.imdb_id,
                "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
                "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
                "last_modified": movie.last_modified,
                "status": movie.status.status if movie.status else None,
                "recommendations": movie.recommendations,
                "watch_history": movie.watch_history,
            }
        )

    return results


# ============== Static File Serving ==============

current_dir = Path(__file__).parent
static_path = current_dir.parent / "frontend" / "dist"

if static_path.exists():
    assets_path = static_path / "assets"
    if assets_path.exists():
        app.mount(
            "/assets",
            StaticFiles(directory=str(assets_path)),
            name="assets",
        )
    logger.info("Static files mounted from: %s", static_path)
else:
    logger.warning("Static directory not found. Looked for: %s", static_path)


@app.get("/manifest.json")
async def serve_manifest():
    """Serve PWA manifest."""
    manifest_file = static_path / "manifest.json"
    if manifest_file.exists():
        return FileResponse(str(manifest_file), media_type="application/json")
    raise HTTPException(status_code=404, detail="Manifest not found")


@app.get("/sw.js")
async def serve_service_worker():
    """Serve service worker."""
    sw_file = static_path / "sw.js"
    if sw_file.exists():
        return FileResponse(str(sw_file), media_type="application/javascript")
    raise HTTPException(status_code=404, detail="Service worker not found")


@app.get("/icon-{size}.png")
async def serve_icon(size: str):
    """Serve PWA icons."""
    icon_file = static_path / f"icon-{size}.png"
    if icon_file.exists():
        return FileResponse(str(icon_file), media_type="image/png")
    favicon_file = static_path / "vite.svg"
    if favicon_file.exists():
        return FileResponse(str(favicon_file), media_type="image/svg+xml")
    raise HTTPException(status_code=404, detail="Icon not found")


@app.get("/vite.svg")
async def serve_vite_svg():
    """Serve favicon."""
    favicon_file = static_path / "vite.svg"
    if favicon_file.exists():
        return FileResponse(str(favicon_file), media_type="image/svg+xml")
    raise HTTPException(status_code=404, detail="Favicon not found")


@app.get("/{full_path:path}")
async def serve_frontend(full_path: str):
    """Serve the PWA frontend for all non-API routes (SPA routing)."""
    if full_path.startswith(("api/", "docs", "redoc", "openapi.json")):
        raise HTTPException(status_code=404, detail="Endpoint not found")

    index_file = static_path / "index.html"
    if index_file.exists():
        return FileResponse(str(index_file))

    raise HTTPException(
        status_code=500,
        detail="Frontend not built. Run 'cd frontend && npm run build' first.",
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
