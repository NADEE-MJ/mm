from __future__ import annotations

import time

from app.schemas.exercises import ExerciseCreate, ExerciseOut, ExerciseUpdate
from app.services.notifications import notify_exercise_updated
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, Query
from models import Exercise, User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/exercises", tags=["exercises"])


@router.get("", response_model=list[ExerciseOut])
async def list_exercises(
    muscle_groups: int | None = Query(default=None, description="Bitmask of MuscleGroup bits"),
    weight_type: int | None = Query(default=None),
    workout_type: int | None = Query(default=None),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[Exercise]:
    query = db.query(Exercise).filter(Exercise.user_id == user.id)

    if muscle_groups is not None:
        query = query.filter((Exercise.muscle_groups.op("&")(muscle_groups)) != 0)
    if weight_type is not None:
        query = query.filter(Exercise.weight_type == weight_type)
    if workout_type is not None:
        query = query.filter(Exercise.workout_type == workout_type)

    return query.order_by(Exercise.name.asc()).all()


@router.post("", response_model=ExerciseOut)
async def create_exercise(
    payload: ExerciseCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> Exercise:
    item = Exercise(
        user_id=user.id,
        name=payload.name,
        description=payload.description,
        video_url=payload.video_url,
        muscle_groups=payload.muscle_groups,
        workout_type=payload.workout_type,
        weight_type=payload.weight_type,
        warmup_sets=payload.warmup_sets,
        accessories=payload.accessories,
        goal_reps_min=payload.goal_reps_min,
        goal_reps_max=payload.goal_reps_max,
        show_highest_set=payload.show_highest_set,
        track_highest_set=payload.track_highest_set,
        highest_set_weight=payload.highest_set_weight,
        highest_set_reps=payload.highest_set_reps,
        show_one_rep_max=payload.show_one_rep_max,
        track_one_rep_max=payload.track_one_rep_max,
        one_rep_max=payload.one_rep_max,
        is_system=False,
        last_modified=time.time(),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    await notify_exercise_updated(user.id, item.id)
    return item


@router.get("/{exercise_id}", response_model=ExerciseOut)
async def get_exercise(
    exercise_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> Exercise:
    item = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Exercise not found")
    if item.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    return item


@router.put("/{exercise_id}", response_model=ExerciseOut)
async def update_exercise(
    exercise_id: str,
    payload: ExerciseUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> Exercise:
    item = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Exercise not found")

    if item.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify another user's exercise")

    updates = payload.model_dump(exclude_unset=True)
    if updates.get("accessories") is None and "accessories" in updates:
        updates["accessories"] = []
    if updates.get("warmup_sets") is None and "warmup_sets" in updates:
        updates["warmup_sets"] = 0
    if updates.get("weight_type") is None and "weight_type" in updates:
        updates.pop("weight_type")
    if updates.get("show_highest_set") is None and "show_highest_set" in updates:
        updates["show_highest_set"] = False
    if updates.get("track_highest_set") is None and "track_highest_set" in updates:
        updates["track_highest_set"] = False
    if updates.get("show_one_rep_max") is None and "show_one_rep_max" in updates:
        updates["show_one_rep_max"] = False
    if updates.get("track_one_rep_max") is None and "track_one_rep_max" in updates:
        updates["track_one_rep_max"] = False
    for key, value in updates.items():
        setattr(item, key, value)
    item.last_modified = time.time()

    db.add(item)
    db.commit()
    db.refresh(item)
    await notify_exercise_updated(user.id, item.id)
    return item


@router.delete("/{exercise_id}")
async def delete_exercise(
    exercise_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    item = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Exercise not found")
    if item.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot delete another user's exercise")

    db.delete(item)
    db.commit()
    await notify_exercise_updated(user.id, exercise_id)
    return {"success": True}
