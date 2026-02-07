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
from sqlalchemy.orm import Session

router = APIRouter(prefix="/backup", tags=["backup"])


@router.get("/export")
async def export_backup(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Export all user data as a JSON download."""
    payload = await backup_manager.build_backup_payload(db, user.id)
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
