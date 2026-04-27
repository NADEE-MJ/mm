from __future__ import annotations

import time

from app.schemas.templates import (
    ReorderTemplateExercises,
    TemplateExerciseCreate,
    TemplateExerciseOut,
    TemplateExerciseUpdate,
    WorkoutTemplateCreate,
    WorkoutTemplateOut,
    WorkoutTemplateUpdate,
)
from app.services.notifications import notify_template_updated
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, HTTPException
from models import User, WorkoutTemplate, WorkoutTemplateExercise
from sqlalchemy.orm import Session, joinedload

router = APIRouter(prefix="/templates", tags=["templates"])


@router.get("", response_model=list[WorkoutTemplateOut])
async def list_templates(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[WorkoutTemplate]:
    return (
        db.query(WorkoutTemplate)
        .options(joinedload(WorkoutTemplate.exercises))
        .filter(WorkoutTemplate.user_id == user.id)
        .order_by(WorkoutTemplate.name.asc())
        .all()
    )


@router.post("", response_model=WorkoutTemplateOut)
async def create_template(
    payload: WorkoutTemplateCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutTemplate:
    now = time.time()
    template = WorkoutTemplate(
        user_id=user.id,
        name=payload.name,
        description=payload.description,
        workout_type_id=payload.workout_type_id,
        is_system=False,
        created_at=now,
        last_modified=now,
    )
    db.add(template)
    db.flush()

    if payload.clone_from:
        source = (
            db.query(WorkoutTemplate)
            .options(joinedload(WorkoutTemplate.exercises))
            .filter(WorkoutTemplate.id == payload.clone_from)
            .first()
        )
        if not source:
            raise HTTPException(status_code=404, detail="clone_from template not found")
        if source.user_id != user.id:
            raise HTTPException(status_code=403, detail="Cannot clone template")

        for item in sorted(source.exercises, key=lambda ex: ex.position):
            db.add(
                WorkoutTemplateExercise(
                    template_id=template.id,
                    exercise_id=item.exercise_id,
                    position=item.position,
                    default_sets=item.default_sets,
                    default_reps=item.default_reps,
                    default_weight=item.default_weight,
                    default_duration_secs=item.default_duration_secs,
                    default_distance=item.default_distance,
                    notes=item.notes,
                    last_modified=now,
                )
            )

    db.commit()
    db.refresh(template)
    await notify_template_updated(user.id, template.id)
    return (
        db.query(WorkoutTemplate)
        .options(joinedload(WorkoutTemplate.exercises))
        .filter(WorkoutTemplate.id == template.id)
        .first()
    )


@router.get("/{template_id}", response_model=WorkoutTemplateOut)
async def get_template(
    template_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutTemplate:
    template = (
        db.query(WorkoutTemplate)
        .options(joinedload(WorkoutTemplate.exercises))
        .filter(WorkoutTemplate.id == template_id)
        .first()
    )
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    return template


@router.put("/{template_id}", response_model=WorkoutTemplateOut)
async def update_template(
    template_id: str,
    payload: WorkoutTemplateUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutTemplate:
    template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify another user's template")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(template, key, value)
    template.last_modified = time.time()
    db.add(template)
    db.commit()
    await notify_template_updated(user.id, template.id)
    return (
        db.query(WorkoutTemplate)
        .options(joinedload(WorkoutTemplate.exercises))
        .filter(WorkoutTemplate.id == template.id)
        .first()
    )


@router.delete("/{template_id}")
async def delete_template(
    template_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot delete another user's template")

    db.delete(template)
    db.commit()
    await notify_template_updated(user.id, template_id)
    return {"success": True}


@router.post("/{template_id}/exercises", response_model=TemplateExerciseOut)
async def add_template_exercise(
    template_id: str,
    payload: TemplateExerciseCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutTemplateExercise:
    template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify this template")

    item = WorkoutTemplateExercise(
        template_id=template_id,
        exercise_id=payload.exercise_id,
        position=payload.position,
        default_sets=payload.default_sets,
        default_reps=payload.default_reps,
        default_weight=payload.default_weight,
        default_duration_secs=payload.default_duration_secs,
        default_distance=payload.default_distance,
        notes=payload.notes,
        last_modified=time.time(),
    )
    template.last_modified = time.time()
    db.add(item)
    db.add(template)
    db.commit()
    db.refresh(item)
    await notify_template_updated(user.id, template_id)
    return item


@router.put("/{template_id}/exercises/{template_exercise_id}", response_model=TemplateExerciseOut)
async def update_template_exercise(
    template_id: str,
    template_exercise_id: str,
    payload: TemplateExerciseUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutTemplateExercise:
    template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify this template")

    item = (
        db.query(WorkoutTemplateExercise)
        .filter(
            WorkoutTemplateExercise.id == template_exercise_id,
            WorkoutTemplateExercise.template_id == template_id,
        )
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="Template exercise not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    item.last_modified = time.time()
    template.last_modified = time.time()
    db.add(item)
    db.add(template)
    db.commit()
    db.refresh(item)
    await notify_template_updated(user.id, template_id)
    return item


@router.delete("/{template_id}/exercises/{template_exercise_id}")
async def delete_template_exercise(
    template_id: str,
    template_exercise_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify this template")

    item = (
        db.query(WorkoutTemplateExercise)
        .filter(
            WorkoutTemplateExercise.id == template_exercise_id,
            WorkoutTemplateExercise.template_id == template_id,
        )
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="Template exercise not found")

    db.delete(item)
    template.last_modified = time.time()
    db.add(template)
    db.commit()
    await notify_template_updated(user.id, template_id)
    return {"success": True}


@router.post("/{template_id}/reorder", response_model=list[TemplateExerciseOut])
async def reorder_template_exercises(
    template_id: str,
    payload: ReorderTemplateExercises,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[WorkoutTemplateExercise]:
    template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.user_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot modify this template")

    items = (
        db.query(WorkoutTemplateExercise)
        .filter(WorkoutTemplateExercise.template_id == template_id)
        .all()
    )
    item_by_id = {item.id: item for item in items}

    for position, item_id in enumerate(payload.exercise_ids):
        if item_id in item_by_id:
            item_by_id[item_id].position = position
            item_by_id[item_id].last_modified = time.time()

    template.last_modified = time.time()
    db.add(template)
    db.commit()

    await notify_template_updated(user.id, template_id)
    return (
        db.query(WorkoutTemplateExercise)
        .filter(WorkoutTemplateExercise.template_id == template_id)
        .order_by(WorkoutTemplateExercise.position.asc())
        .all()
    )
