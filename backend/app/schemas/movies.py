"""Pydantic schemas that model movie-centric payloads."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class RecommendationCreate(BaseModel):
    person_id: Optional[int] = None
    person_name: Optional[str] = None
    # Backward compatibility with legacy clients.
    person: Optional[str] = None
    date_recommended: Optional[float] = None
    vote_type: bool | str = True
    tmdb_data: Optional[dict] = None
    omdb_data: Optional[dict] = None

    @field_validator("vote_type", mode="before")
    @classmethod
    def normalize_vote_type(cls, value: bool | str) -> bool:
        if isinstance(value, bool):
            return value
        text = str(value).strip().lower()
        return text in {"upvote", "1", "true", "t", "yes"}

    model_config = ConfigDict(from_attributes=True)


class BulkRecommendationCreate(BaseModel):
    person_ids: List[int] = Field(default_factory=list)
    people: List[str] = Field(default_factory=list)
    date_recommended: Optional[float] = None
    vote_type: bool | str = True
    tmdb_data: Optional[dict] = None
    omdb_data: Optional[dict] = None

    @field_validator("vote_type", mode="before")
    @classmethod
    def normalize_vote_type(cls, value: bool | str) -> bool:
        if isinstance(value, bool):
            return value
        text = str(value).strip().lower()
        return text in {"upvote", "1", "true", "t", "yes"}

    model_config = ConfigDict(from_attributes=True)


class RecommendationResponse(BaseModel):
    id: int
    imdb_id: str
    user_id: str
    person_id: int
    person_name: str
    # Backward compatibility field for older mobile clients.
    person: Optional[str] = None
    date_recommended: float
    vote_type: bool = True

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
