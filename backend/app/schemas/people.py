"""Schemas for person/recommender related endpoints."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.movies import MovieResponse


class PersonCreate(BaseModel):
    name: str
    is_trusted: bool = False
    color: Optional[str] = None
    emoji: Optional[str] = None
    quick_key: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class PersonResponse(BaseModel):
    id: int
    name: str
    user_id: Optional[str] = None
    is_trusted: bool
    color: Optional[str] = None
    emoji: Optional[str] = None
    quick_key: Optional[str] = None
    last_modified: Optional[float] = None
    movie_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class PersonUpdate(BaseModel):
    name: Optional[str] = None
    is_trusted: Optional[bool] = None
    color: Optional[str] = None
    emoji: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class PersonStatsResponse(BaseModel):
    id: int
    name: str
    is_trusted: bool
    total_movies: int
    watched_movies: int
    average_rating: Optional[float] = None
    movies: List[MovieResponse] = Field(default_factory=list)
    color: Optional[str] = None
    emoji: Optional[str] = None
    quick_key: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)
