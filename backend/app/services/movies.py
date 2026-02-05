"""Movie-centric helpers shared across routers."""

from __future__ import annotations

import json
import time
from typing import Iterable, List

from models import Movie, MovieStatus
from sqlalchemy.orm import Session


def get_or_create_movie(
    db: Session,
    user_id: str,
    imdb_id: str,
    tmdb_data: dict | None = None,
    omdb_data: dict | None = None,
) -> Movie:
    """Fetch a movie for a user or insert the default record when missing."""
    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == imdb_id, Movie.user_id == user_id)
        .first()
    )
    if movie:
        return movie

    movie = Movie(
        imdb_id=imdb_id,
        user_id=user_id,
        tmdb_data=json.dumps(tmdb_data) if tmdb_data else None,
        omdb_data=json.dumps(omdb_data) if omdb_data else None,
    )
    db.add(movie)

    status = MovieStatus(imdb_id=imdb_id, user_id=user_id, status="toWatch")
    db.add(status)
    db.commit()
    db.refresh(movie)
    return movie


def serialize_movie(movie: Movie) -> dict:
    """Serialize a SQLAlchemy movie instance into API-friendly dicts."""
    return {
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


def serialize_movies(movies: Iterable[Movie]) -> List[dict]:
    """Serialize a collection of movies."""
    return [serialize_movie(movie) for movie in movies]
