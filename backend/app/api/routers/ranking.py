"""Ranking routes — binary search movie ranking."""

from __future__ import annotations

from typing import List

from auth import get_required_user
from app.schemas.ranking import RankingEntry, RankingInsertRequest, UnrankedEntry
from app.services.notifications import notify_movie_change
from app.services.ranking import (
    get_ranked_list,
    get_unranked_pool,
    insert_at_position,
    remove_from_ranking,
)
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import Movie, MovieRanking, MovieStatus, User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/ranking", tags=["ranking"])


@router.get("", response_model=List[RankingEntry])
async def get_ranking(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get the full ranked list ordered by position (1 = best)."""
    return get_ranked_list(db, user.id)


@router.get("/unranked", response_model=List[UnrankedEntry])
async def get_unranked(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get watched movies that have not yet been placed in the ranked list."""
    return get_unranked_pool(db, user.id)


@router.post("/insert", response_model=RankingEntry, status_code=status.HTTP_201_CREATED)
async def insert_ranking(
    request: RankingInsertRequest,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Insert a movie at a given position in the ranking."""
    movie = (
        db.query(Movie)
        .filter(Movie.imdb_id == request.imdb_id, Movie.user_id == user.id)
        .first()
    )
    if not movie:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found"
        )

    movie_status = (
        db.query(MovieStatus)
        .filter(MovieStatus.imdb_id == request.imdb_id, MovieStatus.user_id == user.id)
        .first()
    )
    if not movie_status or movie_status.status != "watched":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only watched movies can be ranked",
        )

    existing = (
        db.query(MovieRanking)
        .filter(
            MovieRanking.imdb_id == request.imdb_id,
            MovieRanking.user_id == user.id,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Movie is already ranked",
        )

    insert_at_position(db, user.id, request.imdb_id, request.position, request.liked)
    db.commit()

    await notify_movie_change(user.id, request.imdb_id)

    ranked = get_ranked_list(db, user.id)
    entry = next((r for r in ranked if r["imdb_id"] == request.imdb_id), None)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve ranking after insert",
        )
    return entry


@router.delete("/{imdb_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_ranking(
    imdb_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Remove a movie from the ranked list."""
    existing = (
        db.query(MovieRanking)
        .filter(MovieRanking.imdb_id == imdb_id, MovieRanking.user_id == user.id)
        .first()
    )
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Ranking not found"
        )

    remove_from_ranking(db, user.id, imdb_id)
    db.commit()

    await notify_movie_change(user.id, imdb_id)
    return None
