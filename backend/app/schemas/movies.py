"""Pydantic schemas that model movie-centric payloads."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class RecommendationCreate(BaseModel):
    person: str
    date_recommended: Optional[float] = None
    vote_type: str = "upvote"  # 'upvote' or 'downvote'
    tmdb_data: Optional[dict] = None
    omdb_data: Optional[dict] = None

    model_config = ConfigDict(from_attributes=True)


class RecommendationResponse(BaseModel):
    id: int
    imdb_id: str
    user_id: str
    person: str
    date_recommended: float
    vote_type: str = "upvote"

    model_config = ConfigDict(from_attributes=True)


class WatchHistoryCreate(BaseModel):
    date_watched: float
    my_rating: float = Field(..., ge=1.0, le=10.0)

    model_config = ConfigDict(from_attributes=True)


class WatchHistoryResponse(BaseModel):
    imdb_id: str
    user_id: str
    date_watched: float
    my_rating: float

    model_config = ConfigDict(from_attributes=True)


class MovieStatusUpdate(BaseModel):
    status: str = Field(..., pattern="^(toWatch|watched|deleted|custom)$")
    custom_list_id: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class MovieResponse(BaseModel):
    imdb_id: str
    user_id: Optional[str] = None
    tmdb_data: Optional[dict] = None
    omdb_data: Optional[dict] = None
    last_modified: float
    status: Optional[str] = None
    recommendations: List[RecommendationResponse] = Field(default_factory=list)
    watch_history: Optional[WatchHistoryResponse] = None

    model_config = ConfigDict(from_attributes=True)
