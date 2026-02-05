"""People/recommenders routes."""

from __future__ import annotations

from typing import List

from auth import get_required_user
from app.schemas.people import (
    PersonCreate,
    PersonResponse,
    PersonStatsResponse,
    PersonUpdate,
)
from app.services.movies import serialize_movie
from app.services.notifications import notify_people_change
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import Movie, Person, Recommendation, User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/people", tags=["people"])


@router.get("", response_model=List[PersonResponse])
async def get_people(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get all people for the current user."""
    return db.query(Person).filter(Person.user_id == user.id).all()


@router.post("", response_model=PersonResponse, status_code=status.HTTP_201_CREATED)
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

    db_person = Person(
        name=person.name,
        user_id=user.id,
        is_trusted=person.is_trusted,
        is_default=person.is_default,
        color=person.color or "#0a84ff",
        emoji=person.emoji,
    )
    db.add(db_person)
    db.commit()
    db.refresh(db_person)

    await notify_people_change(user.id)
    return db_person


@router.put("/{name}", response_model=PersonResponse)
async def update_person(
    name: str,
    person_update: PersonUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Update a person's metadata."""
    person = (
        db.query(Person).filter(Person.name == name, Person.user_id == user.id).first()
    )
    if not person:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Person not found"
        )

    if person_update.is_trusted is not None:
        person.is_trusted = person_update.is_trusted
    if person_update.color is not None:
        person.color = person_update.color
    if person_update.emoji is not None:
        person.emoji = person_update.emoji
    db.commit()
    db.refresh(person)

    await notify_people_change(user.id)
    return person


@router.get("/{name}/stats", response_model=PersonStatsResponse)
async def get_person_stats(
    name: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get stats for a specific person including their movies."""
    person = (
        db.query(Person).filter(Person.name == name, Person.user_id == user.id).first()
    )
    if not person:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Person not found"
        )

    recommendations = (
        db.query(Recommendation)
        .filter(Recommendation.person == name, Recommendation.user_id == user.id)
        .all()
    )

    movie_imdb_ids = [r.imdb_id for r in recommendations]
    movies = (
        db.query(Movie)
        .filter(Movie.imdb_id.in_(movie_imdb_ids), Movie.user_id == user.id)
        .all()
        if movie_imdb_ids
        else []
    )

    total_movies = len(movies)
    watched_movies = 0
    total_rating = 0.0
    rated_count = 0

    for movie in movies:
        status_value = movie.status.status if movie.status else None
        if status_value == "watched":
            watched_movies += 1
        if movie.watch_history:
            total_rating += movie.watch_history.my_rating
            rated_count += 1

    average_rating = round(total_rating / rated_count, 1) if rated_count else None

    return {
        "name": person.name,
        "is_trusted": person.is_trusted,
        "is_default": person.is_default,
        "total_movies": total_movies,
        "watched_movies": watched_movies,
        "average_rating": average_rating,
        "movies": [serialize_movie(movie) for movie in movies],
        "color": person.color,
        "emoji": person.emoji,
    }
