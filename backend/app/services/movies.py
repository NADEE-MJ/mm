"""Movie-centric helpers shared across routers."""

from __future__ import annotations

import json
import time
from typing import Iterable, List, Tuple

from models import Movie, MovieStatus
from sqlalchemy.orm import Session


def get_or_create_movie(
    db: Session,
    user_id: str,
    imdb_id: str,
    tmdb_data: dict | None = None,
    omdb_data: dict | None = None,
    media_type: str | None = None,
) -> Movie:
    """Fetch a movie for a user or insert the default record when missing."""
    movie, _ = get_or_create_movie_with_state(
        db=db,
        user_id=user_id,
        imdb_id=imdb_id,
        tmdb_data=tmdb_data,
        omdb_data=omdb_data,
        media_type=media_type,
    )
    return movie


def get_or_create_movie_with_state(
    db: Session,
    user_id: str,
    imdb_id: str,
    tmdb_data: dict | None = None,
    omdb_data: dict | None = None,
    media_type: str | None = None,
) -> Tuple[Movie, bool]:
    """Fetch a movie for a user or insert the default record when missing.

    Returns:
        tuple[Movie, bool]: (movie, created)
    """
    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == imdb_id, Movie.user_id == user_id)
        .first()
    )
    if movie:
        updated = False
        normalized_media_type = (
            media_type if media_type in {"movie", "tv"} else None
        )
        if normalized_media_type and movie.media_type != normalized_media_type:
            movie.media_type = normalized_media_type
            updated = True
        if tmdb_data and not movie.tmdb_data:
            movie.tmdb_data = json.dumps(tmdb_data)
            updated = True
        if omdb_data and not movie.omdb_data:
            movie.omdb_data = json.dumps(omdb_data)
            updated = True
        if updated:
            movie.last_modified = time.time()
            db.flush()
        return movie, False

    movie = Movie(
        imdb_id=imdb_id,
        user_id=user_id,
        tmdb_data=json.dumps(tmdb_data) if tmdb_data else None,
        omdb_data=json.dumps(omdb_data) if omdb_data else None,
        media_type=media_type if media_type in {"movie", "tv"} else "movie",
    )
    db.add(movie)

    status = MovieStatus(imdb_id=imdb_id, user_id=user_id, status="toWatch")
    db.add(status)
    db.flush()
    return movie, True


def serialize_movie(movie: Movie) -> dict:
    """Serialize a SQLAlchemy movie instance into API-friendly dicts."""
    return {
        "imdb_id": movie.imdb_id,
        "user_id": movie.user_id,
        "tmdb_data": json.loads(movie.tmdb_data) if movie.tmdb_data else None,
        "omdb_data": json.loads(movie.omdb_data) if movie.omdb_data else None,
        "media_type": movie.media_type or "movie",
        "last_modified": movie.last_modified,
        "status": movie.status.status if movie.status else None,
        "recommendations": [
            {
                "id": r.id,
                "imdb_id": r.imdb_id,
                "user_id": r.user_id,
                "person_id": r.person_id,
                "person_name": r.person_ref.name if r.person_ref else "",
                # Backward compatibility for older clients.
                "person": r.person_ref.name if r.person_ref else "",
                "date_recommended": r.date_recommended,
                "vote_type": bool(getattr(r, "vote_type", True)),
            }
            for r in movie.recommendations
        ],
        "watch_history": {
            "imdb_id": movie.watch_history.imdb_id,
            "user_id": movie.watch_history.user_id,
            "date_watched": movie.watch_history.date_watched,
            "my_rating": movie.watch_history.my_rating,
        }
        if movie.watch_history
        else None,
    }


def serialize_movies(movies: Iterable[Movie]) -> List[dict]:
    """Serialize a collection of movies."""
    return [serialize_movie(movie) for movie in movies]
