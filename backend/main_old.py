"""FastAPI main application for movie recommendations."""

import json
import logging
import time
from pathlib import Path
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.orm import Session

from database import get_db, engine
from models import Base, Movie, Recommendation, WatchHistory, Person, MovieStatus

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create tables (in case migrations weren't run)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Movie Recommendations API", version="1.0.0")

# CORS configuration - allow frontend dev server access during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],  # React dev server
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
    status: str = Field(..., pattern="^(toWatch|watched|questionable|deleted)$")

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

    model_config = ConfigDict(from_attributes=True)


class PersonResponse(BaseModel):
    name: str
    is_trusted: bool

    model_config = ConfigDict(from_attributes=True)


class PersonUpdate(BaseModel):
    is_trusted: bool

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
def get_or_create_movie(db: Session, imdb_id: str, tmdb_data: dict = None, omdb_data: dict = None) -> Movie:
    """Get existing movie or create new one."""
    movie = db.query(Movie).filter(Movie.imdb_id == imdb_id).first()
    if not movie:
        movie = Movie(
            imdb_id=imdb_id,
            tmdb_data=json.dumps(tmdb_data) if tmdb_data else None,
            omdb_data=json.dumps(omdb_data) if omdb_data else None,
        )
        db.add(movie)
        # Create default status
        status = MovieStatus(imdb_id=imdb_id, status="toWatch")
        db.add(status)
        db.commit()
        db.refresh(movie)
    return movie


# API Endpoints
@app.get("/api/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": time.time()}


@app.post("/api/movies/{imdb_id}/recommendations", response_model=RecommendationResponse, status_code=status.HTTP_201_CREATED)
async def add_recommendation(
    imdb_id: str,
    recommendation: RecommendationCreate,
    db: Session = Depends(get_db)
):
    """Add a recommendation for a movie."""
    # Ensure movie exists
    movie = get_or_create_movie(db, imdb_id)

    # Check if recommendation already exists
    existing = db.query(Recommendation).filter(
        Recommendation.imdb_id == imdb_id,
        Recommendation.person == recommendation.person
    ).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Recommendation from this person already exists"
        )

    # Create recommendation
    db_recommendation = Recommendation(
        imdb_id=imdb_id,
        person=recommendation.person,
        date_recommended=recommendation.date_recommended or time.time()
    )
    db.add(db_recommendation)

    # Ensure person exists
    person = db.query(Person).filter(Person.name == recommendation.person).first()
    if not person:
        person = Person(name=recommendation.person, is_trusted=False)
        db.add(person)

    # Update movie's last_modified
    movie.last_modified = time.time()

    db.commit()
    db.refresh(db_recommendation)

    return db_recommendation


@app.delete("/api/movies/{imdb_id}/recommendations/{person}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_recommendation(
    imdb_id: str,
    person: str,
    db: Session = Depends(get_db)
):
    """Remove a recommendation."""
    recommendation = db.query(Recommendation).filter(
        Recommendation.imdb_id == imdb_id,
        Recommendation.person == person
    ).first()

    if not recommendation:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recommendation not found")

    db.delete(recommendation)

    # Update movie's last_modified
    movie = db.query(Movie).filter(Movie.imdb_id == imdb_id).first()
    if movie:
        movie.last_modified = time.time()

    db.commit()
    return None


@app.put("/api/movies/{imdb_id}/watch", response_model=WatchHistoryResponse)
async def mark_watched(
    imdb_id: str,
    watch_data: WatchHistoryCreate,
    db: Session = Depends(get_db)
):
    """Mark a movie as watched with rating."""
    # Ensure movie exists
    movie = get_or_create_movie(db, imdb_id)

    # Check if already watched
    existing = db.query(WatchHistory).filter(WatchHistory.imdb_id == imdb_id).first()

    if existing:
        # Update existing
        existing.date_watched = watch_data.date_watched
        existing.my_rating = watch_data.my_rating
        db_watch = existing
    else:
        # Create new
        db_watch = WatchHistory(
            imdb_id=imdb_id,
            date_watched=watch_data.date_watched,
            my_rating=watch_data.my_rating
        )
        db.add(db_watch)

    # Update movie status to watched
    movie_status = db.query(MovieStatus).filter(MovieStatus.imdb_id == imdb_id).first()
    if movie_status:
        movie_status.status = "watched"
    else:
        movie_status = MovieStatus(imdb_id=imdb_id, status="watched")
        db.add(movie_status)

    # Update movie's last_modified
    movie.last_modified = time.time()

    db.commit()
    db.refresh(db_watch)

    return db_watch


@app.put("/api/movies/{imdb_id}/status", response_model=dict)
async def update_movie_status(
    imdb_id: str,
    status_update: MovieStatusUpdate,
    db: Session = Depends(get_db)
):
    """Update movie status."""
    # Ensure movie exists
    movie = get_or_create_movie(db, imdb_id)

    # Update or create status
    movie_status = db.query(MovieStatus).filter(MovieStatus.imdb_id == imdb_id).first()
    if movie_status:
        movie_status.status = status_update.status
    else:
        movie_status = MovieStatus(imdb_id=imdb_id, status=status_update.status)
        db.add(movie_status)

    # Update movie's last_modified
    movie.last_modified = time.time()

    db.commit()

    return {"imdb_id": imdb_id, "status": status_update.status, "last_modified": movie.last_modified}


@app.get("/api/movies/{imdb_id}", response_model=MovieResponse)
async def get_movie(imdb_id: str, db: Session = Depends(get_db)):
    """Get movie details with recommendations and watch history."""
    movie = db.query(Movie).filter(Movie.imdb_id == imdb_id).first()

    if not movie:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")

    # Build response
    response = {
        "imdb_id": movie.imdb_id,
        "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
        "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
        "last_modified": movie.last_modified,
        "status": movie.status.status if movie.status else None,
        "recommendations": movie.recommendations,
        "watch_history": movie.watch_history
    }

    return response


@app.get("/api/movies", response_model=List[MovieResponse])
async def get_all_movies(db: Session = Depends(get_db)):
    """Get all movies."""
    movies = db.query(Movie).all()

    results = []
    for movie in movies:
        results.append({
            "imdb_id": movie.imdb_id,
            "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
            "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
            "last_modified": movie.last_modified,
            "status": movie.status.status if movie.status else None,
            "recommendations": movie.recommendations,
            "watch_history": movie.watch_history
        })

    return results


@app.get("/api/sync")
async def sync_get_changes(since: float = 0, db: Session = Depends(get_db)):
    """Get all changes since timestamp for sync."""
    movies = db.query(Movie).filter(Movie.last_modified > since).all()

    results = []
    for movie in movies:
        results.append({
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
                    "date_recommended": r.date_recommended
                }
                for r in movie.recommendations
            ],
            "watch_history": {
                "imdb_id": movie.watch_history.imdb_id,
                "date_watched": movie.watch_history.date_watched,
                "my_rating": movie.watch_history.my_rating
            } if movie.watch_history else None
        })

    return {"movies": results, "timestamp": time.time()}


@app.post("/api/sync", response_model=SyncResponse)
async def sync_process_action(action: SyncAction, db: Session = Depends(get_db)):
    """Process a queued sync action."""
    try:
        action_type = action.action
        data = action.data

        if action_type == "addRecommendation":
            imdb_id = data.get("imdb_id")
            person = data.get("person")
            movie = get_or_create_movie(db, imdb_id, data.get("tmdb_data"), data.get("omdb_data"))

            # Check if recommendation already exists
            existing = db.query(Recommendation).filter(
                Recommendation.imdb_id == imdb_id,
                Recommendation.person == person
            ).first()

            if not existing:
                db_recommendation = Recommendation(
                    imdb_id=imdb_id,
                    person=person,
                    date_recommended=data.get("date_recommended", time.time())
                )
                db.add(db_recommendation)

                # Ensure person exists
                person_obj = db.query(Person).filter(Person.name == person).first()
                if not person_obj:
                    person_obj = Person(name=person, is_trusted=False)
                    db.add(person_obj)

            movie.last_modified = time.time()
            db.commit()

            return SyncResponse(success=True, last_modified=movie.last_modified)

        elif action_type == "markWatched":
            imdb_id = data.get("imdb_id")
            movie = get_or_create_movie(db, imdb_id)

            existing = db.query(WatchHistory).filter(WatchHistory.imdb_id == imdb_id).first()
            if existing:
                existing.date_watched = data.get("date_watched")
                existing.my_rating = data.get("my_rating")
            else:
                db_watch = WatchHistory(
                    imdb_id=imdb_id,
                    date_watched=data.get("date_watched"),
                    my_rating=data.get("my_rating")
                )
                db.add(db_watch)

            # Update status
            movie_status = db.query(MovieStatus).filter(MovieStatus.imdb_id == imdb_id).first()
            if movie_status:
                movie_status.status = "watched"
            else:
                movie_status = MovieStatus(imdb_id=imdb_id, status="watched")
                db.add(movie_status)

            movie.last_modified = time.time()
            db.commit()

            return SyncResponse(success=True, last_modified=movie.last_modified)

        elif action_type == "updateStatus":
            imdb_id = data.get("imdb_id")
            new_status = data.get("status")
            movie = get_or_create_movie(db, imdb_id)

            movie_status = db.query(MovieStatus).filter(MovieStatus.imdb_id == imdb_id).first()
            if movie_status:
                movie_status.status = new_status
            else:
                movie_status = MovieStatus(imdb_id=imdb_id, status=new_status)
                db.add(movie_status)

            movie.last_modified = time.time()
            db.commit()

            return SyncResponse(success=True, last_modified=movie.last_modified)

        elif action_type == "addPerson":
            name = data.get("name")
            person = db.query(Person).filter(Person.name == name).first()
            if not person:
                person = Person(name=name, is_trusted=data.get("is_trusted", False))
                db.add(person)
                db.commit()

            return SyncResponse(success=True, last_modified=time.time())

        elif action_type == "updatePersonTrust":
            name = data.get("name")
            person = db.query(Person).filter(Person.name == name).first()
            if person:
                person.is_trusted = data.get("is_trusted")
                db.commit()

            return SyncResponse(success=True, last_modified=time.time())

        else:
            return SyncResponse(success=False, error=f"Unknown action type: {action_type}")

    except Exception as e:
        db.rollback()
        return SyncResponse(success=False, error=str(e))


@app.get("/api/people", response_model=List[PersonResponse])
async def get_people(db: Session = Depends(get_db)):
    """Get all people."""
    people = db.query(Person).all()
    return people


@app.post("/api/people", response_model=PersonResponse, status_code=status.HTTP_201_CREATED)
async def add_person(person: PersonCreate, db: Session = Depends(get_db)):
    """Add a new person."""
    existing = db.query(Person).filter(Person.name == person.name).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Person already exists"
        )

    db_person = Person(name=person.name, is_trusted=person.is_trusted)
    db.add(db_person)
    db.commit()
    db.refresh(db_person)

    return db_person


@app.put("/api/people/{name}", response_model=PersonResponse)
async def update_person(name: str, person_update: PersonUpdate, db: Session = Depends(get_db)):
    """Update person's trusted status."""
    person = db.query(Person).filter(Person.name == name).first()
    if not person:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Person not found")

    person.is_trusted = person_update.is_trusted
    db.commit()
    db.refresh(person)

    return person


# Static file serving for production PWA
current_dir = Path(__file__).parent
static_path = current_dir.parent / "frontend" / "dist"

if static_path.exists():
    # Mount assets directory (JS, CSS, images, etc.)
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
    logger.warning("Frontend not built. Run 'cd frontend && npm run build' first.")


# Serve PWA files directly from root
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
    # Return vite.svg as fallback if icons don't exist
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
    logger.debug("Catch-all route accessed with path: %s", full_path)

    # If it's an API route, return 404
    if full_path.startswith(("api/", "docs", "redoc", "openapi.json")):
        logger.warning("API endpoint not found (catch-all): %s", full_path)
        raise HTTPException(status_code=404, detail="Endpoint not found")

    # For all other routes, serve the frontend index.html to support SPA routing
    index_file = static_path / "index.html"
    if index_file.exists():
        logger.debug("Serving index.html for SPA route: %s", full_path)
        return FileResponse(str(index_file))

    logger.error("index.html not found at: %s", index_file)
    raise HTTPException(
        status_code=500,
        detail="Frontend not built. Run 'cd frontend && npm run build' first."
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
