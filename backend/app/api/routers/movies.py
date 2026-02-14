"""Movie-related routes."""

from __future__ import annotations

import time
import json
from typing import List

from auth import get_required_user
from app.schemas.movies import (
    BulkRecommendationCreate,
    MovieResponse,
    MovieStatusUpdate,
    RecommendationCreate,
    RecommendationResponse,
    WatchHistoryCreate,
    WatchHistoryResponse,
)
from app.services.external_apis import (
    get_omdb_movie,
    get_tmdb_movie_details,
    get_tmdb_tv_details,
)
from app.services.movies import (
    get_or_create_movie,
    get_or_create_movie_with_state,
    serialize_movie,
    serialize_movies,
)
from app.services.notifications import (
    notify_movie_added,
    notify_movie_change,
    notify_people_change,
)
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import Movie, MovieStatus, Person, Recommendation, User, WatchHistory
from sqlalchemy.orm import Session

router = APIRouter(prefix="/movies", tags=["movies"])


def _normalize_vote_type(value: object) -> bool:
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    return text in {"upvote", "1", "true", "t", "yes"}


def _resolve_person(
    db: Session,
    user_id: str,
    *,
    person_id: int | None = None,
    person_name: str | None = None,
    legacy_person: str | None = None,
) -> tuple[Person, bool]:
    """Resolve a person either by ID or name, creating when needed by name."""
    if person_id is not None:
        person = (
            db.query(Person)
            .filter(Person.id == person_id, Person.user_id == user_id)
            .first()
        )
        if not person:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Person id {person_id} not found",
            )
        return person, False

    candidate_name = (person_name or legacy_person or "").strip()
    if not candidate_name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Either person_id or person_name/person is required",
        )

    person = (
        db.query(Person)
        .filter(Person.name == candidate_name, Person.user_id == user_id)
        .first()
    )
    if person:
        return person, False

    person = Person(name=candidate_name, user_id=user_id, is_trusted=False)
    db.add(person)
    db.flush()
    return person, True


@router.post(
    "/{imdb_id}/recommendations",
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
    movie, created = get_or_create_movie_with_state(
        db,
        user.id,
        imdb_id,
        recommendation.tmdb_data,
        recommendation.omdb_data,
        recommendation.media_type or "movie",
    )
    person, created_person = _resolve_person(
        db,
        user.id,
        person_id=recommendation.person_id,
        person_name=recommendation.person_name,
        legacy_person=recommendation.person,
    )
    normalized_vote = _normalize_vote_type(recommendation.vote_type)

    existing = (
        db.query(Recommendation)
        .filter(
            Recommendation.imdb_id == imdb_id,
            Recommendation.user_id == user.id,
            Recommendation.person_id == person.id,
        )
        .first()
    )

    if existing:
        # Update existing vote if vote_type changed
        existing.vote_type = normalized_vote
        existing.date_recommended = recommendation.date_recommended or time.time()
        db_recommendation = existing
    else:
        # Create new vote
        db_recommendation = Recommendation(
            imdb_id=imdb_id,
            user_id=user.id,
            person_id=person.id,
            date_recommended=recommendation.date_recommended or time.time(),
            vote_type=normalized_vote,
        )
        db.add(db_recommendation)

    movie.last_modified = time.time()
    db.commit()
    db.refresh(db_recommendation)

    if created:
        await notify_movie_added(user.id, imdb_id)
    else:
        await notify_movie_change(user.id, imdb_id)
    if created_person:
        await notify_people_change(user.id)

    return db_recommendation


@router.post(
    "/{imdb_id}/recommendations/bulk",
    response_model=List[RecommendationResponse],
    status_code=status.HTTP_201_CREATED,
)
async def add_bulk_recommendations(
    imdb_id: str,
    bulk_recommendation: BulkRecommendationCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Add multiple recommendations for a movie at once."""
    movie, created = get_or_create_movie_with_state(
        db,
        user.id,
        imdb_id,
        bulk_recommendation.tmdb_data,
        bulk_recommendation.omdb_data,
        bulk_recommendation.media_type or "movie",
    )

    recommendations = []
    created_people = set()

    # Support IDs and names in one request; de-dupe by resolved person id.
    resolved_people: dict[int, Person] = {}

    for person_id in bulk_recommendation.person_ids:
        person, _ = _resolve_person(db, user.id, person_id=person_id)
        resolved_people[person.id] = person

    for person_name in bulk_recommendation.people:
        person, created_person = _resolve_person(
            db, user.id, person_name=person_name, legacy_person=person_name
        )
        resolved_people[person.id] = person
        if created_person:
            created_people.add(person.name)

    normalized_vote = _normalize_vote_type(bulk_recommendation.vote_type)

    for person in resolved_people.values():
        existing = (
            db.query(Recommendation)
            .filter(
                Recommendation.imdb_id == imdb_id,
                Recommendation.user_id == user.id,
                Recommendation.person_id == person.id,
            )
            .first()
        )

        if existing:
            # Update existing recommendation
            existing.vote_type = normalized_vote
            existing.date_recommended = bulk_recommendation.date_recommended or time.time()
            db_recommendation = existing
        else:
            # Create new recommendation
            db_recommendation = Recommendation(
                imdb_id=imdb_id,
                user_id=user.id,
                person_id=person.id,
                date_recommended=bulk_recommendation.date_recommended or time.time(),
                vote_type=normalized_vote,
            )
            db.add(db_recommendation)

        recommendations.append(db_recommendation)

    movie.last_modified = time.time()
    db.commit()

    # Refresh all recommendations
    for rec in recommendations:
        db.refresh(rec)

    # Send notifications
    if created:
        await notify_movie_added(user.id, imdb_id)
    else:
        await notify_movie_change(user.id, imdb_id)
    if created_people:
        await notify_people_change(user.id)

    return recommendations


@router.delete(
    "/{imdb_id}/recommendations/{person}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_recommendation(
    imdb_id: str,
    person: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Remove a recommendation."""
    if person.isdigit():
        recommendation = (
            db.query(Recommendation)
            .filter(
                Recommendation.imdb_id == imdb_id,
                Recommendation.user_id == user.id,
                Recommendation.person_id == int(person),
            )
            .first()
        )
    else:
        person_row = (
            db.query(Person)
            .filter(Person.name == person, Person.user_id == user.id)
            .first()
        )
        recommendation = (
            db.query(Recommendation)
            .filter(
                Recommendation.imdb_id == imdb_id,
                Recommendation.user_id == user.id,
                Recommendation.person_id == person_row.id,
            )
            .first()
            if person_row
            else None
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
    await notify_movie_change(user.id, imdb_id)
    return None


@router.put("/{imdb_id}/watch", response_model=WatchHistoryResponse)
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

    await notify_movie_change(user.id, imdb_id)
    return db_watch


@router.put("/{imdb_id}/status", response_model=dict)
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

    await notify_movie_change(user.id, imdb_id)

    return {
        "imdb_id": imdb_id,
        "status": status_update.status,
        "custom_list_id": movie_status.custom_list_id,
        "last_modified": movie.last_modified,
    }


@router.get("/{imdb_id}", response_model=MovieResponse)
async def get_movie(
    imdb_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
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

    return serialize_movie(movie)


@router.get("", response_model=List[MovieResponse])
async def get_all_movies(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get all movies for the current user."""
    movies = db.query(Movie).filter(Movie.user_id == user.id).all()
    return serialize_movies(movies)


@router.post("/{imdb_id}/refresh", response_model=dict)
async def refresh_movie_metadata(
    imdb_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Refresh TMDB + OMDB data for an existing movie."""
    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == imdb_id, Movie.user_id == user.id)
        .first()
    )
    if not movie:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Movie not found",
        )

    updated_tmdb = False
    updated_omdb = False

    tmdb_payload = json.loads(movie.tmdb_data) if movie.tmdb_data else {}
    tmdb_id = tmdb_payload.get("tmdbId") or tmdb_payload.get("id")
    if tmdb_id:
        is_tv = (movie.media_type or "").strip().lower() == "tv"
        if not is_tv:
            is_tv = str(tmdb_payload.get("mediaType") or "").strip().lower() == "tv"

        if is_tv:
            tmdb_data = await get_tmdb_tv_details(int(tmdb_id), force_refresh=True)
        else:
            tmdb_data = await get_tmdb_movie_details(int(tmdb_id), force_refresh=True)
        movie.tmdb_data = json.dumps(tmdb_data)
        updated_tmdb = True

    omdb_data = await get_omdb_movie(imdb_id, force_refresh=True)
    movie.omdb_data = json.dumps(omdb_data)
    updated_omdb = True

    movie.last_modified = time.time()
    db.commit()

    await notify_movie_change(user.id, imdb_id)

    return {
        "success": True,
        "updated": {"tmdb": updated_tmdb, "omdb": updated_omdb},
        "last_modified": movie.last_modified,
    }
