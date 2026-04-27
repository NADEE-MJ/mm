"""Ranking service — binary search insertion into liked/disliked sub-lists.

Liked movies:    scores in range (5, 10].  Position 1 = best = 10.
Disliked movies: scores in range [1, 5].   Position 1 = least bad = 5.

Score formulas
--------------
Liked   (N movies, p = position 1..N):  score = 10 - (p-1) * 5 / N
Disliked (M movies, p = position 1..M): score = 5  - (p-1) * 4 / M

"Levels of accuracy": ceil(log2(N+1)) comparisons are needed to place a new
movie — more movies in the list → more comparisons → finer score granularity.
"""

from __future__ import annotations

import json
import time
from typing import List

from models import Movie, MovieRanking, MovieStatus
from sqlalchemy.orm import Session


# ---------------------------------------------------------------------------
# Score helpers
# ---------------------------------------------------------------------------

def compute_liked_score(position: int, n_liked: int) -> float:
    """Score for a liked movie at 1-indexed *position* in a group of *n_liked*.

    Range: (5, 10].  n_liked=1 → 10.0.  As n_liked grows, last position → 5+.
    """
    if n_liked <= 0:
        return 7.5
    return round(10.0 - (position - 1) * 5.0 / n_liked, 1)


def compute_disliked_score(position: int, n_disliked: int) -> float:
    """Score for a disliked movie at 1-indexed *position* in a group of *n_disliked*.

    Range: [1, 5].  n_disliked=1 → 5.0.  As n_disliked grows, last position → 1+.
    """
    if n_disliked <= 0:
        return 5.0
    return round(5.0 - (position - 1) * 4.0 / n_disliked, 1)


def recalculate_scores(db: Session, user_id: str) -> None:
    """Recompute all scores for both liked and disliked groups after any mutation."""
    for liked_val in (True, False):
        rankings = (
            db.query(MovieRanking)
            .filter(MovieRanking.user_id == user_id, MovieRanking.liked == liked_val)
            .order_by(MovieRanking.position)
            .all()
        )
        total = len(rankings)
        for ranking in rankings:
            if liked_val:
                ranking.score = compute_liked_score(ranking.position, total)
            else:
                ranking.score = compute_disliked_score(ranking.position, total)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def _extract_title_poster_year(movie: Movie) -> tuple[str, str | None, str | None]:
    """Pull display fields from the JSON blobs stored in Movie."""
    tmdb = json.loads(movie.tmdb_data) if movie.tmdb_data else {}
    omdb = json.loads(movie.omdb_data) if movie.omdb_data else {}

    title = tmdb.get("title") or omdb.get("title") or movie.imdb_id
    poster_path = (
        tmdb.get("poster")
        or tmdb.get("posterSmall")
        or tmdb.get("poster_path")
        or omdb.get("poster")
    )
    year_raw = tmdb.get("year") or omdb.get("year")
    year = str(year_raw) if year_raw is not None else None
    return title, poster_path, year


# ---------------------------------------------------------------------------
# Read operations
# ---------------------------------------------------------------------------

def get_ranked_list(db: Session, user_id: str) -> List[dict]:
    """Return all ranked movies: liked first (by position), then disliked (by position)."""
    rankings = (
        db.query(MovieRanking)
        .filter(MovieRanking.user_id == user_id)
        .order_by(MovieRanking.liked.desc(), MovieRanking.position)
        .all()
    )

    result = []
    for ranking in rankings:
        movie = (
            db.query(Movie)
            .filter(Movie.imdb_id == ranking.imdb_id, Movie.user_id == user_id)
            .first()
        )
        if not movie:
            continue
        title, poster_path, year = _extract_title_poster_year(movie)
        result.append(
            {
                "imdb_id": ranking.imdb_id,
                "position": ranking.position,
                "score": ranking.score,
                "liked": ranking.liked,
                "ranked_at": ranking.ranked_at,
                "title": title,
                "poster_path": poster_path,
                "year": year,
            }
        )
    return result


def get_unranked_pool(db: Session, user_id: str) -> List[dict]:
    """Return watched movies that have not yet been placed in the ranked list."""
    watched_ids = {
        row.imdb_id
        for row in db.query(MovieStatus.imdb_id)
        .filter(MovieStatus.user_id == user_id, MovieStatus.status == "watched")
        .all()
    }

    ranked_ids = {
        row.imdb_id
        for row in db.query(MovieRanking.imdb_id)
        .filter(MovieRanking.user_id == user_id)
        .all()
    }

    unranked_ids = watched_ids - ranked_ids

    result = []
    for imdb_id in unranked_ids:
        movie = (
            db.query(Movie)
            .filter(Movie.imdb_id == imdb_id, Movie.user_id == user_id)
            .first()
        )
        if not movie:
            continue
        title, poster_path, year = _extract_title_poster_year(movie)
        result.append(
            {
                "imdb_id": imdb_id,
                "title": title,
                "poster_path": poster_path,
                "year": year,
            }
        )
    return result


# ---------------------------------------------------------------------------
# Write operations
# ---------------------------------------------------------------------------

def insert_at_position(
    db: Session, user_id: str, imdb_id: str, position: int, liked: bool
) -> MovieRanking:
    """Shift rows in the same liked/disliked group ≥ position, insert, recalculate scores."""
    group_total = (
        db.query(MovieRanking)
        .filter(MovieRanking.user_id == user_id, MovieRanking.liked == liked)
        .count()
    )

    position = max(1, min(position, group_total + 1))

    # Shift rows in the same group downward.
    # Flush one-at-a-time in descending order so each slot is vacated before
    # the next row tries to occupy it (SQLite checks UNIQUE per-row immediately).
    rows_to_shift = (
        db.query(MovieRanking)
        .filter(
            MovieRanking.user_id == user_id,
            MovieRanking.liked == liked,
            MovieRanking.position >= position,
        )
        .order_by(MovieRanking.position.desc())
        .all()
    )
    for row in rows_to_shift:
        row.position += 1
        db.flush()

    new_ranking = MovieRanking(
        imdb_id=imdb_id,
        user_id=user_id,
        liked=liked,
        position=position,
        score=0.0,
        ranked_at=time.time(),
    )
    db.add(new_ranking)
    db.flush()

    recalculate_scores(db, user_id)
    return new_ranking


def remove_from_ranking(db: Session, user_id: str, imdb_id: str) -> None:
    """Delete a ranking entry, renumber within the same group, recalculate scores."""
    ranking = (
        db.query(MovieRanking)
        .filter(MovieRanking.user_id == user_id, MovieRanking.imdb_id == imdb_id)
        .first()
    )
    if not ranking:
        return

    deleted_position = ranking.position
    deleted_liked = ranking.liked
    db.delete(ranking)
    db.flush()

    # Shift rows down one-at-a-time in ascending order so each vacated slot
    # is filled before the next row moves into it.
    rows_after = (
        db.query(MovieRanking)
        .filter(
            MovieRanking.user_id == user_id,
            MovieRanking.liked == deleted_liked,
            MovieRanking.position > deleted_position,
        )
        .order_by(MovieRanking.position)
        .all()
    )
    for row in rows_after:
        row.position -= 1
        db.flush()

    recalculate_scores(db, user_id)
