"""Manual export/import routes for backups."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from app.services.backup import backup_manager
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Body, Depends, HTTPException, status
from fastapi.responses import Response
from models import User
from pydantic import BaseModel
from sqlalchemy.orm import Session

router = APIRouter(prefix="/backup", tags=["backup"])


class BackupSettingsUpdate(BaseModel):
    backup_enabled: bool


@router.get("/export")
async def export_backup(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Export all user data as a JSON download."""
    payload = await backup_manager.build_condensed_payload(db, user.id)
    exported_date = datetime.now(timezone.utc).date().isoformat()
    filename = f"moviemanager-export-{exported_date}.json"
    return Response(
        content=json.dumps(payload, indent=2),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/import")
async def import_backup(
    payload: dict[str, Any] = Body(...),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Import user data from a JSON payload."""
    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Backup payload must be a JSON object",
        )

    return await backup_manager.restore_from_backup(db, user.id, payload=payload)


@router.get("/settings")
async def get_backup_settings(
    user: User = Depends(get_required_user),
):
    """Read current user's backup preference."""
    return {"backup_enabled": bool(getattr(user, "backup_enabled", False))}


@router.put("/settings")
async def update_backup_settings(
    settings: BackupSettingsUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Update current user's backup preference."""
    user.backup_enabled = bool(settings.backup_enabled)
    db.commit()
    db.refresh(user)
    return {"backup_enabled": bool(user.backup_enabled)}


@router.get("/list")
async def list_backups(
    user: User = Depends(get_required_user),
):
    """List available server-side backups for the current user."""
    return {"backups": backup_manager.list_backups(user.id)}


@router.post("/restore/{filename}")
async def restore_backup_file(
    filename: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Restore user data from a specific backup file stored on the server."""
    backup_file = backup_manager.get_backup_file(user.id, filename)
    if backup_file is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Backup file not found",
        )

    return await backup_manager.restore_from_backup(
        db,
        user.id,
        backup_file=backup_file,
    )
