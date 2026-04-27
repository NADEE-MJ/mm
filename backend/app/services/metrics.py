"""Metrics calculations for streak, volume, PRs, and charts."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone

from models import Exercise, SessionExercise, SessionSet, WorkoutSession, WorkoutTemplate, WorkoutType
from sqlalchemy import func
from sqlalchemy.orm import Session


def epley_1rm(weight: float | None, reps: int | None) -> float | None:
    if weight is None or reps is None or reps <= 0:
        return None
    return round(weight * (1 + (reps / 30.0)), 2)


def session_volume(session: WorkoutSession) -> float:
    total = 0.0
    for session_exercise in session.exercises:
        for set_row in session_exercise.sets:
            if not set_row.completed:
                continue
            if set_row.weight is not None and set_row.reps:
                total += float(set_row.weight) * float(set_row.reps)
            elif set_row.distance is not None:
                total += float(set_row.distance)
            elif set_row.duration_secs is not None:
                total += float(set_row.duration_secs)
    return round(total, 2)


def calculate_streak(db: Session, user_id: str) -> tuple[int, int]:
    rows = (
        db.query(WorkoutSession.date)
        .filter(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
        .order_by(WorkoutSession.date.desc())
        .all()
    )

    if not rows:
        return 0, 0

    day_set = {
        datetime.fromtimestamp(value, tz=timezone.utc).date()
        for (value,) in rows
    }

    today = datetime.now(timezone.utc).date()
    current_anchor = today if today in day_set else (today - timedelta(days=1))

    current = 0
    cursor = current_anchor
    while cursor in day_set:
        current += 1
        cursor -= timedelta(days=1)

    longest = 0
    for day in sorted(day_set):
        run = 1
        cursor = day
        while (cursor + timedelta(days=1)) in day_set:
            run += 1
            cursor += timedelta(days=1)
        if run > longest:
            longest = run

    return current, longest


def summary(db: Session, user_id: str) -> dict:
    sessions = (
        db.query(WorkoutSession)
        .filter(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
        .all()
    )
    total_volume = 0.0
    for session in sessions:
        db.refresh(session)
    sessions = (
        db.query(WorkoutSession)
        .filter(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
        .all()
    )

    for session in sessions:
        _ = session.exercises
        total_volume += session_volume(session)

    current_streak, longest_streak = calculate_streak(db, user_id)
    pr_count = len(all_prs(db, user_id))

    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "total_sessions": len(sessions),
        "total_volume": round(total_volume, 2),
        "pr_count": pr_count,
    }


def calendar(db: Session, user_id: str, year: int, month: int) -> list[dict]:
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    if month == 12:
        end = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
    else:
        end = datetime(year, month + 1, 1, tzinfo=timezone.utc)

    rows = (
        db.query(WorkoutSession)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "completed",
            WorkoutSession.date >= start.timestamp(),
            WorkoutSession.date < end.timestamp(),
        )
        .all()
    )

    grouped: dict[str, list[WorkoutSession]] = defaultdict(list)
    for row in rows:
        date_key = datetime.fromtimestamp(row.date, tz=timezone.utc).date().isoformat()
        grouped[date_key].append(row)

    result: list[dict] = []
    for date_key, day_sessions in sorted(grouped.items()):
        volume = sum(session_volume(session) for session in day_sessions)
        result.append(
            {
                "date": date_key,
                "session_count": len(day_sessions),
                "volume": round(volume, 2),
            }
        )
    return result


def exercise_progress(db: Session, user_id: str, exercise_id: str) -> list[dict]:
    rows = (
        db.query(WorkoutSession.date, SessionSet.weight, SessionSet.reps)
        .join(SessionExercise, SessionExercise.session_id == WorkoutSession.id)
        .join(SessionSet, SessionSet.session_exercise_id == SessionExercise.id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "completed",
            SessionExercise.exercise_id == exercise_id,
            SessionSet.completed.is_(True),
        )
        .order_by(WorkoutSession.date.asc(), SessionSet.set_number.asc())
        .all()
    )

    return [
        {
            "timestamp": row[0],
            "weight": row[1],
            "reps": row[2],
            "estimated_1rm": epley_1rm(row[1], row[2]),
        }
        for row in rows
    ]


def frequency(db: Session, user_id: str, weeks: int = 8) -> list[dict]:
    now = datetime.now(timezone.utc)
    start = (now - timedelta(weeks=weeks)).timestamp()

    rows = (
        db.query(WorkoutSession.date, WorkoutType.slug)
        .outerjoin(WorkoutTemplate, WorkoutTemplate.id == WorkoutSession.template_id)
        .outerjoin(WorkoutType, WorkoutType.id == WorkoutTemplate.workout_type_id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "completed",
            WorkoutSession.date >= start,
        )
        .all()
    )

    grouped: dict[tuple[str, str], int] = defaultdict(int)
    for ts, slug in rows:
        date = datetime.fromtimestamp(ts, tz=timezone.utc).date()
        week_start = (date - timedelta(days=date.weekday())).isoformat()
        grouped[(week_start, slug or "custom")] += 1

    return [
        {"week_start": week_start, "workout_type": workout_type, "sessions": count}
        for (week_start, workout_type), count in sorted(grouped.items())
    ]


def all_prs(db: Session, user_id: str) -> list[dict]:
    # Per exercise + reps max weight and when achieved.
    rows = (
        db.query(
            SessionExercise.exercise_id,
            SessionSet.reps,
            func.max(SessionSet.weight).label("max_weight"),
        )
        .join(SessionSet, SessionSet.session_exercise_id == SessionExercise.id)
        .join(WorkoutSession, WorkoutSession.id == SessionExercise.session_id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "completed",
            SessionSet.completed.is_(True),
            SessionSet.weight.is_not(None),
        )
        .group_by(SessionExercise.exercise_id, SessionSet.reps)
        .all()
    )

    exercise_names = {
        ex.id: ex.name
        for ex in db.query(Exercise).filter(Exercise.id.in_([row[0] for row in rows])).all()
    }

    results: list[dict] = []
    for exercise_id, reps, max_weight in rows:
        achieved_at = (
            db.query(func.max(WorkoutSession.date))
            .join(SessionExercise, SessionExercise.session_id == WorkoutSession.id)
            .join(SessionSet, SessionSet.session_exercise_id == SessionExercise.id)
            .filter(
                WorkoutSession.user_id == user_id,
                SessionExercise.exercise_id == exercise_id,
                SessionSet.reps == reps,
                SessionSet.weight == max_weight,
                SessionSet.completed.is_(True),
            )
            .scalar()
        )
        results.append(
            {
                "exercise_id": exercise_id,
                "exercise_name": exercise_names.get(exercise_id, "Unknown"),
                "reps": reps,
                "weight": float(max_weight),
                "achieved_at": float(achieved_at or 0),
            }
        )

    results.sort(key=lambda item: (item["exercise_name"], item["reps"] or 0))
    return results
