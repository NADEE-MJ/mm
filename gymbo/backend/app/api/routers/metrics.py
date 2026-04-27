from __future__ import annotations

from datetime import datetime, timezone

from app.schemas.metrics import (
    CalendarMetric,
    ExerciseProgressPoint,
    FrequencyPoint,
    MetricsSummary,
    PRRecord,
    StreakOut,
)
from app.services import metrics as metrics_service
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, Query
from models import User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/metrics", tags=["metrics"])


@router.get("/summary", response_model=MetricsSummary)
async def summary(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    return metrics_service.summary(db, user.id)


@router.get("/calendar", response_model=list[CalendarMetric])
async def calendar(
    year: int | None = Query(default=None),
    month: int | None = Query(default=None),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    now = datetime.now(timezone.utc)
    return metrics_service.calendar(db, user.id, year or now.year, month or now.month)


@router.get("/exercise/{exercise_id}", response_model=list[ExerciseProgressPoint])
async def exercise_progress(
    exercise_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    return metrics_service.exercise_progress(db, user.id, exercise_id)


@router.get("/frequency", response_model=list[FrequencyPoint])
async def frequency(
    weeks: int = Query(default=8, ge=1, le=52),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    return metrics_service.frequency(db, user.id, weeks)


@router.get("/prs", response_model=list[PRRecord])
async def prs(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    return metrics_service.all_prs(db, user.id)


@router.get("/streak", response_model=StreakOut)
async def streak(
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    current_streak, longest_streak = metrics_service.calculate_streak(db, user.id)
    return {"current_streak": current_streak, "longest_streak": longest_streak}
