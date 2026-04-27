"""Workout session domain helpers."""

from __future__ import annotations

import time
from collections import defaultdict

from models import (
    Exercise,
    SessionExercise,
    SessionSet,
    WorkoutSession,
    WorkoutTemplate,
    WorkoutTemplateExercise,
)
from sqlalchemy.orm import Session, joinedload


def serialize_session(session: WorkoutSession) -> dict:
    return {
        "id": session.id,
        "user_id": session.user_id,
        "template_id": session.template_id,
        "date": session.date,
        "started_at": session.started_at,
        "finished_at": session.finished_at,
        "duration_secs": session.duration_secs,
        "notes": session.notes,
        "status": session.status,
        "last_modified": session.last_modified,
        "exercises": [
            {
                "id": ex.id,
                "session_id": ex.session_id,
                "exercise_id": ex.exercise_id,
                "position": ex.position,
                "notes": ex.notes,
                "last_modified": ex.last_modified,
                "sets": [
                    {
                        "id": s.id,
                        "session_exercise_id": s.session_exercise_id,
                        "set_number": s.set_number,
                        "reps": s.reps,
                        "weight": s.weight,
                        "duration_secs": s.duration_secs,
                        "distance": s.distance,
                        "is_warmup": s.is_warmup,
                        "used_accessories": s.used_accessories or [],
                        "band_color": s.band_color,
                        "completed": s.completed,
                        "last_modified": s.last_modified,
                    }
                    for s in sorted(ex.sets, key=lambda item: item.set_number)
                ],
            }
            for ex in sorted(session.exercises, key=lambda item: item.position)
        ],
    }


def _group_sets_by_exercise(session: WorkoutSession) -> dict[str, list[SessionSet]]:
    grouped: dict[str, list[SessionSet]] = defaultdict(list)
    for session_exercise in session.exercises:
        for set_row in session_exercise.sets:
            grouped[session_exercise.exercise_id].append(set_row)
    for exercise_id, set_rows in grouped.items():
        grouped[exercise_id] = sorted(set_rows, key=lambda row: row.set_number)
    return grouped


def _find_prior_session(
    db: Session,
    user_id: str,
    exercise_id: str,
    template_id: str | None,
) -> WorkoutSession | None:
    if template_id:
        primary = (
            db.query(WorkoutSession)
            .join(SessionExercise, SessionExercise.session_id == WorkoutSession.id)
            .filter(
                WorkoutSession.user_id == user_id,
                WorkoutSession.template_id == template_id,
                WorkoutSession.status == "completed",
                SessionExercise.exercise_id == exercise_id,
            )
            .options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets))
            .order_by(WorkoutSession.finished_at.desc().nullslast(), WorkoutSession.date.desc())
            .first()
        )
        if primary:
            return primary

    return (
        db.query(WorkoutSession)
        .join(SessionExercise, SessionExercise.session_id == WorkoutSession.id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "completed",
            SessionExercise.exercise_id == exercise_id,
        )
        .options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets))
        .order_by(WorkoutSession.finished_at.desc().nullslast(), WorkoutSession.date.desc())
        .first()
    )


def get_prior_sets(
    db: Session,
    user_id: str,
    template_id: str | None,
    exercise_id: str,
) -> list[dict]:
    prior_session = _find_prior_session(db, user_id, exercise_id, template_id)
    if not prior_session:
        return []

    grouped = _group_sets_by_exercise(prior_session)
    prior_sets = grouped.get(exercise_id, [])
    return [
        {
            "set_number": set_row.set_number,
            "reps": set_row.reps,
            "weight": set_row.weight,
            "duration_secs": set_row.duration_secs,
            "distance": set_row.distance,
            "is_warmup": set_row.is_warmup,
            "used_accessories": set_row.used_accessories or [],
            "band_color": set_row.band_color,
            "completed": False,
        }
        for set_row in prior_sets
    ]


def populate_session_from_template(
    db: Session,
    user_id: str,
    template: WorkoutTemplate,
    session: WorkoutSession,
) -> None:
    template_exercises = (
        db.query(WorkoutTemplateExercise)
        .options(joinedload(WorkoutTemplateExercise.exercise))
        .filter(WorkoutTemplateExercise.template_id == template.id)
        .order_by(WorkoutTemplateExercise.position.asc())
        .all()
    )

    now = time.time()
    for template_exercise in template_exercises:
        exercise: Exercise | None = template_exercise.exercise
        warmup_sets = max(0, int(exercise.warmup_sets if exercise else 0))
        session_exercise = SessionExercise(
            session_id=session.id,
            exercise_id=template_exercise.exercise_id,
            position=template_exercise.position,
            notes=template_exercise.notes,
            last_modified=now,
        )
        db.add(session_exercise)
        db.flush()

        prior_sets = get_prior_sets(
            db,
            user_id,
            template.id,
            template_exercise.exercise_id,
        )

        if not prior_sets:
            default_sets = template_exercise.default_sets or 3
            for idx in range(default_sets):
                prior_sets.append(
                    {
                        "set_number": idx + 1,
                        "reps": template_exercise.default_reps,
                        "weight": template_exercise.default_weight,
                        "duration_secs": template_exercise.default_duration_secs,
                        "distance": template_exercise.default_distance,
                        "is_warmup": idx < warmup_sets,
                        "used_accessories": [],
                        "band_color": None,
                        "completed": False,
                    }
                )

        for payload in prior_sets:
            db.add(
                SessionSet(
                    session_exercise_id=session_exercise.id,
                    set_number=payload.get("set_number") or 1,
                    reps=payload.get("reps"),
                    weight=payload.get("weight"),
                    duration_secs=payload.get("duration_secs"),
                    distance=payload.get("distance"),
                    is_warmup=bool(payload.get("is_warmup", False)),
                    used_accessories=payload.get("used_accessories") or [],
                    band_color=payload.get("band_color"),
                    completed=False,
                    last_modified=now,
                )
            )


def detect_prs_for_session_completion(db: Session, session: WorkoutSession) -> list[dict]:
    prs: list[dict] = []
    for session_exercise in session.exercises:
        for set_row in session_exercise.sets:
            if not set_row.completed or set_row.weight is None:
                continue

            prior_max = (
                db.query(SessionSet.weight)
                .join(SessionExercise, SessionExercise.id == SessionSet.session_exercise_id)
                .join(WorkoutSession, WorkoutSession.id == SessionExercise.session_id)
                .filter(
                    WorkoutSession.user_id == session.user_id,
                    WorkoutSession.status == "completed",
                    SessionExercise.exercise_id == session_exercise.exercise_id,
                    SessionSet.reps == set_row.reps,
                    SessionSet.completed.is_(True),
                    SessionSet.weight.is_not(None),
                    WorkoutSession.id != session.id,
                )
                .order_by(SessionSet.weight.desc())
                .limit(1)
                .scalar()
            )

            if prior_max is None or set_row.weight > prior_max:
                prs.append(
                    {
                        "exercise_id": session_exercise.exercise_id,
                        "set_id": set_row.id,
                        "reps": set_row.reps,
                        "weight": set_row.weight,
                        "previous_best": prior_max,
                    }
                )

    return prs
