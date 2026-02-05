"""Custom list routes."""

from __future__ import annotations

import uuid
from typing import List

from auth import get_required_user
from app.schemas.lists import (
    CustomListCreate,
    CustomListResponse,
    CustomListUpdate,
)
from app.schemas.movies import MovieResponse
from app.services.movies import serialize_movies
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import CustomList, Movie, MovieStatus, User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/lists", tags=["lists"])


@router.get("", response_model=List[CustomListResponse])
async def get_custom_lists(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get all custom lists for the current user."""
    return (
        db.query(CustomList)
        .filter(CustomList.user_id == user.id)
        .order_by(CustomList.position)
        .all()
    )


@router.post("", response_model=CustomListResponse, status_code=status.HTTP_201_CREATED)
async def create_custom_list(
    list_data: CustomListCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Create a new custom list."""
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


@router.get("/{list_id}", response_model=CustomListResponse)
async def get_custom_list(
    list_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
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


@router.put("/{list_id}", response_model=CustomListResponse)
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


@router.delete("/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_custom_list(
    list_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
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

    db.query(MovieStatus).filter(
        MovieStatus.custom_list_id == list_id, MovieStatus.user_id == user.id
    ).update({"status": "toWatch", "custom_list_id": None})

    db.delete(db_list)
    db.commit()
    return None


@router.get("/{list_id}/movies", response_model=List[MovieResponse])
async def get_custom_list_movies(
    list_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Get all movies in a custom list."""
    db_list = (
        db.query(CustomList)
        .filter(CustomList.id == list_id, CustomList.user_id == user.id)
        .first()
    )
    if not db_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="List not found"
        )

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
    return serialize_movies(movies)
