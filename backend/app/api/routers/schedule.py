from __future__ import annotations

import time
from datetime import datetime, timedelta, timezone

from app.schemas.schedule import ReplaceScheduleRequest, TodayTemplateStatus, WeeklyScheduleEntryOut
from app.services.notifications import notify_schedule_updated
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends
from models import User, WeeklySchedule, WorkoutSession, WorkoutTemplate
from sqlalchemy.orm import Session

router = APIRouter(prefix="/schedule", tags=["schedule"])


@router.get("", response_model=list[WeeklyScheduleEntryOut])
async def get_schedule(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[WeeklySchedule]:
    return (
        db.query(WeeklySchedule)
        .filter(WeeklySchedule.user_id == user.id)
        .order_by(WeeklySchedule.day_of_week.asc())
        .all()
    )


@router.put("", response_model=list[WeeklyScheduleEntryOut])
async def replace_schedule(
    payload: ReplaceScheduleRequest,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[WeeklySchedule]:
    db.query(WeeklySchedule).filter(WeeklySchedule.user_id == user.id).delete()

    now = time.time()
    rows: list[WeeklySchedule] = []
    for entry in payload.entries:
        row = WeeklySchedule(
            user_id=user.id,
            day_of_week=entry.day_of_week,
            template_id=entry.template_id,
            last_modified=now,
        )
        db.add(row)
        rows.append(row)

    db.commit()
    await notify_schedule_updated(user.id)
    return (
        db.query(WeeklySchedule)
        .filter(WeeklySchedule.user_id == user.id)
        .order_by(WeeklySchedule.day_of_week.asc())
        .all()
    )


@router.delete("/{schedule_id}")
async def delete_schedule_entry(
    schedule_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    row = (
        db.query(WeeklySchedule)
        .filter(WeeklySchedule.id == schedule_id, WeeklySchedule.user_id == user.id)
        .first()
    )
    if not row:
        return {"success": False}

    db.delete(row)
    db.commit()
    await notify_schedule_updated(user.id)
    return {"success": True}


@router.get("/today", response_model=list[TodayTemplateStatus])
async def get_today_schedule(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[TodayTemplateStatus]:
    now = datetime.now(timezone.utc)
    day_of_week = now.weekday()
    day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    entries = (
        db.query(WeeklySchedule)
        .filter(WeeklySchedule.user_id == user.id, WeeklySchedule.day_of_week == day_of_week)
        .all()
    )

    templates = {
        t.id: t
        for t in db.query(WorkoutTemplate)
        .filter(WorkoutTemplate.id.in_([entry.template_id for entry in entries if entry.template_id]))
        .all()
    }

    completed_template_ids = {
        template_id
        for (template_id,) in db.query(WorkoutSession.template_id)
        .filter(
            WorkoutSession.user_id == user.id,
            WorkoutSession.status == "completed",
            WorkoutSession.date >= day_start.timestamp(),
            WorkoutSession.date < day_end.timestamp(),
        )
        .all()
        if template_id
    }

    return [
        TodayTemplateStatus(
            schedule_id=entry.id,
            template_id=entry.template_id,
            template_name=templates.get(entry.template_id).name if entry.template_id in templates else None,
            completed_today=bool(entry.template_id and entry.template_id in completed_template_ids),
        )
        for entry in entries
    ]
