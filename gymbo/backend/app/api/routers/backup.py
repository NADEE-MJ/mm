"""Backup import/export endpoints."""

from __future__ import annotations

from typing import Any

from app.services.backup import backup_manager
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, HTTPException
from models import User
from pydantic import BaseModel
from sqlalchemy.orm import Session

router = APIRouter(prefix="/backup", tags=["backup"])


class BackupSettingsUpdate(BaseModel):
    backup_enabled: bool


@router.get("/export")
async def export_backup_payload(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    return await backup_manager.build_backup_payload(db, user.id)


@router.post("/export")
async def write_backup_file(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    path = await backup_manager.backup_user_data(db, user.id)
    return {"success": True, "filename": path.name}


@router.post("/import")
async def import_backup(
    payload: dict[str, Any],
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    return await backup_manager.restore_from_backup(db, user.id, payload=payload)


@router.get("/settings")
async def get_backup_settings(user: User = Depends(get_required_user)) -> dict:
    return {"backup_enabled": user.backup_enabled}


@router.put("/settings")
async def update_backup_settings(
    payload: BackupSettingsUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    user.backup_enabled = payload.backup_enabled
    db.add(user)
    db.commit()
    return {"backup_enabled": user.backup_enabled}


@router.get("/list")
async def list_backups(user: User = Depends(get_required_user)) -> list[dict[str, Any]]:
    return backup_manager.list_backups(user.id)


@router.post("/restore/{filename}")
async def restore_backup(
    filename: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    backup_file = backup_manager.get_backup_file(user.id, filename)
    if not backup_file:
        raise HTTPException(status_code=404, detail="Backup file not found")

    return await backup_manager.restore_from_backup(db, user.id, backup_file=backup_file)
