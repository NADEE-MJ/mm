"""Movie-related routes."""

from __future__ import annotations

import time
from typing import List

from auth import get_required_user
from app.schemas.movies import (
    MovieResponse,
    MovieStatusUpdate,
    RecommendationCreate,
    RecommendationResponse,
    WatchHistoryCreate,
    WatchHistoryResponse,
)
from app.services.movies import get_or_create_movie, serialize_movie, serialize_movies
from app.services.notifications import notify_movie_change, notify_people_change
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import Movie, MovieStatus, Person, Recommendation, User, WatchHistory
from sqlalchemy.orm import Session

router = APIRouter(prefix="/movies", tags=["movies"])


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
    movie = get_or_create_movie(db, user.id, imdb_id)

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

    db_recommendation = Recommendation(
        imdb_id=imdb_id,
        user_id=user.id,
        person=recommendation.person,
        date_recommended=recommendation.date_recommended or time.time(),
    )
    db.add(db_recommendation)

    created_person = False
    person = (
        db.query(Person)
        .filter(Person.name == recommendation.person, Person.user_id == user.id)
        .first()
    )
    if not person:
        person = Person(name=recommendation.person, user_id=user.id, is_trusted=False)
        db.add(person)
        created_person = True

    movie.last_modified = time.time()
    db.commit()
    db.refresh(db_recommendation)

    await notify_movie_change(user.id, imdb_id)
    if created_person:
        await notify_people_change(user.id)

    return db_recommendation


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
