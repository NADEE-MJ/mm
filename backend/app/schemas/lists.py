"""Schemas for custom movie lists."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict


class CustomListCreate(BaseModel):
    name: str
    color: str = "#0a84ff"
    icon: str = "list"
    position: int = 0

    model_config = ConfigDict(from_attributes=True)


class CustomListUpdate(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    position: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class CustomListResponse(BaseModel):
    id: str
    user_id: Optional[str] = None
    name: str
    color: str
    icon: str
    position: int
    created_at: float
    last_modified: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)
