from __future__ import annotations

import time

from app.schemas.exercises import WorkoutTypeCreate, WorkoutTypeOut, WorkoutTypeUpdate
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, HTTPException
from models import User, WorkoutType
from sqlalchemy.orm import Session

router = APIRouter(prefix="/workout-types", tags=["workout-types"])


@router.get("", response_model=list[WorkoutTypeOut])
async def list_workout_types(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[WorkoutType]:
    return (
        db.query(WorkoutType)
        .filter(WorkoutType.user_id == user.id)
        .order_by(WorkoutType.name.asc())
        .all()
    )


@router.post("", response_model=WorkoutTypeOut)
async def create_workout_type(
    payload: WorkoutTypeCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutType:
    existing = (
        db.query(WorkoutType)
        .filter(WorkoutType.user_id == user.id, WorkoutType.slug == payload.slug)
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Workout type slug already exists")

    item = WorkoutType(
        user_id=user.id,
        name=payload.name,
        slug=payload.slug,
        icon=payload.icon,
        color=payload.color,
        is_system=False,
        last_modified=time.time(),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.put("/{workout_type_id}", response_model=WorkoutTypeOut)
async def update_workout_type(
    workout_type_id: str,
    payload: WorkoutTypeUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutType:
    item = db.query(WorkoutType).filter(WorkoutType.id == workout_type_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Workout type not found")
    if item.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify another user's workout type")

    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(item, key, value)
    item.last_modified = time.time()

    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/{workout_type_id}")
async def delete_workout_type(
    workout_type_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    item = db.query(WorkoutType).filter(WorkoutType.id == workout_type_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Workout type not found")
    if item.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot delete another user's workout type")

    db.delete(item)
    db.commit()
    return {"success": True}
