"""Pydantic schemas for the movie ranking feature."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class RankingEntry(BaseModel):
    imdb_id: str
    position: int
    score: float
    liked: bool
    ranked_at: float
    title: str
    poster_path: Optional[str] = None
    year: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class UnrankedEntry(BaseModel):
    imdb_id: str
    title: str
    poster_path: Optional[str] = None
    year: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class RankingInsertRequest(BaseModel):
    imdb_id: str
    position: int = Field(..., ge=1)
    liked: bool

    model_config = ConfigDict(from_attributes=True)
