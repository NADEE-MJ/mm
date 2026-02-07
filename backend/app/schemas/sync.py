"""Schemas powering sync endpoints (single-action + batch)."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict


class SyncAction(BaseModel):
    action: str
    data: dict
    timestamp: float

    model_config = ConfigDict(from_attributes=True)


class SyncResponse(BaseModel):
    success: bool
    last_modified: Optional[float] = None
    error: Optional[str] = None
    conflict: bool = False
    server_state: Optional[dict] = None

    model_config = ConfigDict(from_attributes=True)


class BatchSyncRequest(BaseModel):
    actions: list[SyncAction]
    client_timestamp: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


class BatchSyncResponse(BaseModel):
    results: list[SyncResponse]
    server_timestamp: float

    model_config = ConfigDict(from_attributes=True)
