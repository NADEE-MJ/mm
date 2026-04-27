"""Sync endpoints and WebSocket notifications."""

from __future__ import annotations

import logging
import time
from typing import Optional

from app.schemas.exercises import normalize_muscle_groups, normalize_string_list as normalize_accessory_list
from app.schemas.exercises import normalize_weight_type_int as normalize_weight_type
from app.schemas.sync import BatchSyncRequest, BatchSyncResponse, SyncAction, SyncResponse
from app.services.conflict_resolver import ConflictResolver
from app.services.notifications import (
    notify_exercise_updated,
    notify_schedule_updated,
    notify_session_completed,
    notify_session_updated,
    notify_template_updated,
    sync_notifier,
)
from app.services.security import get_user_from_ws_token
from app.services.sessions import detect_prs_for_session_completion, populate_session_from_template, serialize_session
from auth import get_required_user
from database import SessionLocal, get_db
from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from models import (
    Exercise,
    SessionExercise,
    SessionSet,
    User,
    WeeklySchedule,
    WorkoutSession,
    WorkoutTemplate,
    WorkoutTemplateExercise,
    WorkoutType,
)
from sqlalchemy.orm import Session, joinedload

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["sync"])
ws_router = APIRouter(tags=["sync"])


def _normalize_client_timestamp(value: float | None) -> float | None:
    if value is None:
        return None
    return value / 1000.0 if value > 10_000_000_000 else value


def _normalize_optional_int(value: object) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _normalize_optional_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _normalize_bool(value: object, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"1", "true", "yes", "y", "on"}:
            return True
        if lowered in {"0", "false", "no", "n", "off"}:
            return False
    return default


def _workout_type_payload(item: WorkoutType) -> dict:
    return {
        "id": item.id,
        "user_id": item.user_id,
        "name": item.name,
        "slug": item.slug,
        "icon": item.icon,
        "color": item.color,
        "is_system": item.is_system,
        "last_modified": item.last_modified,
    }


def _exercise_payload(item: Exercise) -> dict:
    return {
        "id": item.id,
        "user_id": item.user_id,
        "name": item.name,
        "description": item.description,
        "muscle_groups": item.muscle_groups or 0,
        "workout_type": item.workout_type,
        "weight_type": item.weight_type,
        "warmup_sets": item.warmup_sets,
        "accessories": item.accessories or [],
        "video_url": item.video_url,
        "goal_reps_min": item.goal_reps_min,
        "goal_reps_max": item.goal_reps_max,
        "show_highest_set": item.show_highest_set,
        "track_highest_set": item.track_highest_set,
        "highest_set_weight": item.highest_set_weight,
        "highest_set_reps": item.highest_set_reps,
        "show_one_rep_max": item.show_one_rep_max,
        "track_one_rep_max": item.track_one_rep_max,
        "one_rep_max": item.one_rep_max,
        "is_system": item.is_system,
        "source_exercise_id": item.source_exercise_id,
        "last_modified": item.last_modified,
    }


def _template_payload(template: WorkoutTemplate) -> dict:
    return {
        "id": template.id,
        "user_id": template.user_id,
        "name": template.name,
        "description": template.description,
        "workout_type_id": template.workout_type_id,
        "is_system": template.is_system,
        "created_at": template.created_at,
        "last_modified": template.last_modified,
        "exercises": [
            {
                "id": item.id,
                "template_id": item.template_id,
                "exercise_id": item.exercise_id,
                "position": item.position,
                "default_sets": item.default_sets,
                "default_reps": item.default_reps,
                "default_weight": item.default_weight,
                "default_duration_secs": item.default_duration_secs,
                "default_distance": item.default_distance,
                "notes": item.notes,
                "last_modified": item.last_modified,
            }
            for item in sorted(template.exercises, key=lambda ex: ex.position)
        ],
    }


def _schedule_payload(item: WeeklySchedule) -> dict:
    return {
        "id": item.id,
        "user_id": item.user_id,
        "day_of_week": item.day_of_week,
        "template_id": item.template_id,
        "last_modified": item.last_modified,
    }


def _query_active_session(db: Session, user_id: str, exclude_session_id: str | None = None) -> WorkoutSession | None:
    query = db.query(WorkoutSession).filter(
        WorkoutSession.user_id == user_id,
        WorkoutSession.status == "in_progress",
    )
    if exclude_session_id:
        query = query.filter(WorkoutSession.id != exclude_session_id)
    return query.order_by(WorkoutSession.started_at.desc().nullslast(), WorkoutSession.date.desc()).first()


def _collect_changes(
    db: Session,
    user_id: str,
    since: float,
    limit: int,
    offset: int,
) -> dict:
    if since <= 0:
        workout_types = db.query(WorkoutType).filter(WorkoutType.user_id == user_id).all()
        exercises = db.query(Exercise).filter(Exercise.user_id == user_id).all()
        templates = (
            db.query(WorkoutTemplate)
            .options(joinedload(WorkoutTemplate.exercises))
            .filter(WorkoutTemplate.user_id == user_id)
            .all()
        )
        schedule = db.query(WeeklySchedule).filter(WeeklySchedule.user_id == user_id).all()
        sessions = (
            db.query(WorkoutSession)
            .options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets))
            .filter(WorkoutSession.user_id == user_id)
            .all()
        )
    else:
        workout_types = (
            db.query(WorkoutType)
            .filter(
                WorkoutType.user_id == user_id,
                WorkoutType.last_modified >= since,
            )
            .all()
        )
        exercises = (
            db.query(Exercise)
            .filter(
                Exercise.user_id == user_id,
                Exercise.last_modified >= since,
            )
            .all()
        )
        templates = (
            db.query(WorkoutTemplate)
            .options(joinedload(WorkoutTemplate.exercises))
            .filter(
                WorkoutTemplate.user_id == user_id,
                WorkoutTemplate.last_modified >= since,
            )
            .all()
        )
        schedule = (
            db.query(WeeklySchedule)
            .filter(WeeklySchedule.user_id == user_id, WeeklySchedule.last_modified >= since)
            .all()
        )
        sessions = (
            db.query(WorkoutSession)
            .options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets))
            .filter(WorkoutSession.user_id == user_id, WorkoutSession.last_modified >= since)
            .all()
        )

    change_rows: list[tuple[str, float, object]] = []
    change_rows.extend(("workout_type", item.last_modified or 0.0, item) for item in workout_types)
    change_rows.extend(("exercise", item.last_modified or 0.0, item) for item in exercises)
    change_rows.extend(("template", item.last_modified or 0.0, item) for item in templates)
    change_rows.extend(("schedule", item.last_modified or 0.0, item) for item in schedule)
    change_rows.extend(("session", item.last_modified or 0.0, item) for item in sessions)
    change_rows.sort(key=lambda row: row[1])

    total = len(change_rows)
    selected = change_rows[offset : offset + limit]

    workout_type_payload: list[dict] = []
    exercise_payload: list[dict] = []
    template_payload: list[dict] = []
    schedule_payload: list[dict] = []
    session_payload: list[dict] = []

    for kind, _changed_at, entity in selected:
        if kind == "workout_type":
            workout_type_payload.append(_workout_type_payload(entity))
        elif kind == "exercise":
            exercise_payload.append(_exercise_payload(entity))
        elif kind == "template":
            template_payload.append(_template_payload(entity))
        elif kind == "schedule":
            schedule_payload.append(_schedule_payload(entity))
        elif kind == "session":
            session_payload.append(serialize_session(entity))

    has_more = (offset + limit) < total
    return {
        "workout_types": workout_type_payload,
        "exercises": exercise_payload,
        "templates": template_payload,
        "schedule": schedule_payload,
        "sessions": session_payload,
        "has_more": has_more,
        "next_offset": (offset + limit) if has_more else None,
        "server_timestamp": time.time(),
    }


async def _broadcast_events(user_id: str, events: list[tuple[str, str | None]]) -> None:
    exercise_ids = sorted({entity_id for event, entity_id in events if event == "exerciseUpdated" and entity_id})
    template_ids = sorted({entity_id for event, entity_id in events if event == "templateUpdated" and entity_id})
    schedule_changed = any(event == "scheduleUpdated" for event, _ in events)
    session_updated_ids = sorted({entity_id for event, entity_id in events if event == "sessionUpdated" and entity_id})
    session_completed_ids = sorted({entity_id for event, entity_id in events if event == "sessionCompleted" and entity_id})

    for exercise_id in exercise_ids:
        await notify_exercise_updated(user_id, exercise_id)
    for template_id in template_ids:
        await notify_template_updated(user_id, template_id)
    if schedule_changed:
        await notify_schedule_updated(user_id)
    for session_id in session_updated_ids:
        await notify_session_updated(user_id, session_id)
    for session_id in session_completed_ids:
        await notify_session_completed(user_id, session_id)


async def _process_sync_action(
    db: Session,
    user: User,
    action: SyncAction,
    events: list[tuple[str, str | None]],
) -> SyncResponse:
    client_timestamp = _normalize_client_timestamp(action.timestamp)
    data = action.data or {}

    try:
        if action.action == "addExercise":
            weight_type = normalize_weight_type(data.get("weight_type") or 4)
            item = Exercise(
                user_id=user.id,
                name=data["name"],
                description=data.get("description"),
                muscle_groups=normalize_muscle_groups(data.get("muscle_groups", 0)),
                workout_type=data.get("workout_type"),
                weight_type=weight_type,
                warmup_sets=max(0, int(data.get("warmup_sets") or 0)),
                accessories=normalize_accessory_list(data.get("accessories")),
                video_url=data.get("video_url"),
                goal_reps_min=_normalize_optional_int(data.get("goal_reps_min")),
                goal_reps_max=_normalize_optional_int(data.get("goal_reps_max")),
                show_highest_set=_normalize_bool(data.get("show_highest_set"), False),
                track_highest_set=_normalize_bool(data.get("track_highest_set"), False),
                highest_set_weight=_normalize_optional_float(data.get("highest_set_weight")),
                highest_set_reps=_normalize_optional_int(data.get("highest_set_reps")),
                show_one_rep_max=_normalize_bool(data.get("show_one_rep_max"), False),
                track_one_rep_max=_normalize_bool(data.get("track_one_rep_max"), False),
                one_rep_max=_normalize_optional_float(data.get("one_rep_max")),
                is_system=False,
                last_modified=time.time(),
            )
            db.add(item)
            db.commit()
            events.append(("exerciseUpdated", item.id))
            return SyncResponse(success=True, last_modified=item.last_modified)

        if action.action == "updateExercise":
            exercise_id = data.get("id")
            item = db.query(Exercise).filter(Exercise.id == exercise_id).first()
            if not item:
                return SyncResponse(success=False, error="Exercise not found")

            if item.user_id != user.id:
                return SyncResponse(success=False, error="Exercise not found")
            target = item

            conflict = ConflictResolver.check_conflict(item, client_timestamp, _exercise_payload)
            if conflict:
                return SyncResponse(success=False, **conflict)

            for field in ["name", "description", "video_url", "workout_type"]:
                if field in data:
                    setattr(target, field, data[field])
            if "muscle_groups" in data:
                target.muscle_groups = normalize_muscle_groups(data["muscle_groups"])
            if "weight_type" in data and data["weight_type"] is not None:
                target.weight_type = normalize_weight_type(data["weight_type"])
            if "warmup_sets" in data:
                target.warmup_sets = max(0, int(data["warmup_sets"] or 0))
            if "accessories" in data:
                target.accessories = normalize_accessory_list(data["accessories"])
            if "goal_reps_min" in data:
                target.goal_reps_min = _normalize_optional_int(data["goal_reps_min"])
            if "goal_reps_max" in data:
                target.goal_reps_max = _normalize_optional_int(data["goal_reps_max"])
            if "show_highest_set" in data:
                target.show_highest_set = _normalize_bool(data["show_highest_set"], False)
            if "track_highest_set" in data:
                target.track_highest_set = _normalize_bool(data["track_highest_set"], False)
            if "highest_set_weight" in data:
                target.highest_set_weight = _normalize_optional_float(data["highest_set_weight"])
            if "highest_set_reps" in data:
                target.highest_set_reps = _normalize_optional_int(data["highest_set_reps"])
            if "show_one_rep_max" in data:
                target.show_one_rep_max = _normalize_bool(data["show_one_rep_max"], False)
            if "track_one_rep_max" in data:
                target.track_one_rep_max = _normalize_bool(data["track_one_rep_max"], False)
            if "one_rep_max" in data:
                target.one_rep_max = _normalize_optional_float(data["one_rep_max"])
            target.last_modified = time.time()
            db.add(target)
            db.commit()
            events.append(("exerciseUpdated", target.id))
            return SyncResponse(success=True, last_modified=target.last_modified)

        if action.action == "deleteExercise":
            exercise_id = data.get("id")
            item = db.query(Exercise).filter(Exercise.id == exercise_id).first()
            if not item:
                return SyncResponse(success=False, error="Exercise not found")
            if item.user_id != user.id:
                return SyncResponse(success=False, error="Exercise not found")
            db.delete(item)
            db.commit()
            events.append(("exerciseUpdated", exercise_id))
            return SyncResponse(success=True, last_modified=time.time())

        if action.action == "addTemplate":
            now = time.time()
            template = WorkoutTemplate(
                user_id=user.id,
                name=data["name"],
                description=data.get("description"),
                workout_type_id=data.get("workout_type_id"),
                is_system=False,
                created_at=now,
                last_modified=now,
            )
            db.add(template)
            db.flush()
            for idx, item in enumerate(data.get("exercises") or []):
                db.add(
                    WorkoutTemplateExercise(
                        template_id=template.id,
                        exercise_id=item["exercise_id"],
                        position=item.get("position", idx),
                        default_sets=item.get("default_sets"),
                        default_reps=item.get("default_reps"),
                        default_weight=item.get("default_weight"),
                        default_duration_secs=item.get("default_duration_secs"),
                        default_distance=item.get("default_distance"),
                        notes=item.get("notes"),
                        last_modified=now,
                    )
                )
            db.commit()
            events.append(("templateUpdated", template.id))
            return SyncResponse(success=True, last_modified=template.last_modified)

        if action.action == "updateTemplate":
            template_id = data.get("id")
            template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
            if not template:
                return SyncResponse(success=False, error="Template not found")
            if template.user_id != user.id:
                return SyncResponse(success=False, error="Template not found")

            conflict = ConflictResolver.check_conflict(template, client_timestamp, _template_payload)
            if conflict:
                return SyncResponse(success=False, **conflict)

            for field in ["name", "description", "workout_type_id"]:
                if field in data:
                    setattr(template, field, data[field])
            template.last_modified = time.time()
            db.add(template)
            db.commit()
            events.append(("templateUpdated", template.id))
            return SyncResponse(success=True, last_modified=template.last_modified)

        if action.action == "deleteTemplate":
            template_id = data.get("id")
            template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
            if not template:
                return SyncResponse(success=False, error="Template not found")
            if template.user_id != user.id:
                return SyncResponse(success=False, error="Template not found")
            db.delete(template)
            db.commit()
            events.append(("templateUpdated", template_id))
            return SyncResponse(success=True, last_modified=time.time())

        if action.action == "updateTemplateExercises":
            template_id = data.get("template_id")
            template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == template_id).first()
            if not template:
                return SyncResponse(success=False, error="Template not found")
            if template.user_id != user.id:
                return SyncResponse(success=False, error="Template not found")

            db.query(WorkoutTemplateExercise).filter(WorkoutTemplateExercise.template_id == template_id).delete()
            now = time.time()
            for idx, item in enumerate(data.get("exercises") or []):
                db.add(
                    WorkoutTemplateExercise(
                        template_id=template_id,
                        exercise_id=item["exercise_id"],
                        position=item.get("position", idx),
                        default_sets=item.get("default_sets"),
                        default_reps=item.get("default_reps"),
                        default_weight=item.get("default_weight"),
                        default_duration_secs=item.get("default_duration_secs"),
                        default_distance=item.get("default_distance"),
                        notes=item.get("notes"),
                        last_modified=now,
                    )
                )
            template.last_modified = now
            db.add(template)
            db.commit()
            events.append(("templateUpdated", template.id))
            return SyncResponse(success=True, last_modified=template.last_modified)

        if action.action == "updateSchedule":
            entries = data.get("entries") if isinstance(data, dict) else None
            if entries is None and isinstance(data, list):
                entries = data
            entries = entries or []

            db.query(WeeklySchedule).filter(WeeklySchedule.user_id == user.id).delete()
            now = time.time()
            for entry in entries:
                db.add(
                    WeeklySchedule(
                        user_id=user.id,
                        day_of_week=entry["day_of_week"],
                        template_id=entry.get("template_id"),
                        last_modified=now,
                    )
                )
            db.commit()
            events.append(("scheduleUpdated", None))
            return SyncResponse(success=True, last_modified=now)

        if action.action == "startSession":
            active_session = _query_active_session(db, user.id)
            if active_session:
                return SyncResponse(
                    success=False,
                    error="You already have an active session. Finish it before starting a new one.",
                )

            now = time.time()
            session = WorkoutSession(
                user_id=user.id,
                template_id=data.get("template_id"),
                date=data.get("date") or now,
                started_at=None,
                notes=data.get("notes"),
                status="in_progress",
                last_modified=now,
            )
            db.add(session)
            db.flush()

            template_id = data.get("template_id")
            if template_id:
                template = db.query(WorkoutTemplate).filter(
                    WorkoutTemplate.id == template_id,
                    WorkoutTemplate.user_id == user.id,
                ).first()
                if template:
                    populate_session_from_template(db, user.id, template, session)

            db.commit()
            events.append(("sessionUpdated", session.id))
            return SyncResponse(success=True, last_modified=session.last_modified)

        if action.action == "updateSession":
            session_id = data.get("id")
            session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
            if not session:
                return SyncResponse(success=False, error="Session not found")

            if data.get("status") == "in_progress":
                active_session = _query_active_session(db, user.id, exclude_session_id=session_id)
                if active_session:
                    return SyncResponse(
                        success=False,
                        error="You already have an active session. Finish it before starting a new one.",
                    )

            conflict = ConflictResolver.check_conflict(session, client_timestamp, serialize_session)
            if conflict:
                return SyncResponse(success=False, **conflict)

            for field in [
                "template_id",
                "date",
                "notes",
                "status",
            ]:
                if field in data:
                    setattr(session, field, data[field])
            session.last_modified = time.time()
            db.add(session)
            db.commit()
            events.append(("sessionUpdated", session.id))
            return SyncResponse(success=True, last_modified=session.last_modified)

        if action.action == "logSet":
            session_id = data.get("session_id")
            session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
            if not session:
                return SyncResponse(success=False, error="Session not found")

            session_exercise_id = data.get("session_exercise_id")
            session_exercise: SessionExercise | None = None
            if session_exercise_id:
                session_exercise = db.query(SessionExercise).filter(
                    SessionExercise.id == session_exercise_id,
                    SessionExercise.session_id == session_id,
                ).first()
            if session_exercise is None and data.get("exercise_id"):
                session_exercise = db.query(SessionExercise).filter(
                    SessionExercise.session_id == session_id,
                    SessionExercise.exercise_id == data.get("exercise_id"),
                ).first()
            if session_exercise is None and data.get("exercise_id"):
                position = (
                    db.query(SessionExercise).filter(SessionExercise.session_id == session_id).count()
                )
                session_exercise = SessionExercise(
                    session_id=session_id,
                    exercise_id=data["exercise_id"],
                    position=position,
                    notes=None,
                    last_modified=time.time(),
                )
                db.add(session_exercise)
                db.flush()

            if session_exercise is None:
                return SyncResponse(success=False, error="Session exercise not found")

            set_number = int(data.get("set_number") or 1)
            set_row = db.query(SessionSet).filter(
                SessionSet.session_exercise_id == session_exercise.id,
                SessionSet.set_number == set_number,
            ).first()

            now = time.time()
            if set_row is None:
                set_row = SessionSet(
                    session_exercise_id=session_exercise.id,
                    set_number=set_number,
                    reps=data.get("reps"),
                    weight=data.get("weight"),
                    duration_secs=data.get("duration_secs"),
                    distance=data.get("distance"),
                    is_warmup=bool(data.get("is_warmup", False)),
                    used_accessories=normalize_accessory_list(data.get("used_accessories")),
                    band_color=data.get("band_color"),
                    completed=bool(data.get("completed", False)),
                    last_modified=now,
                )
            else:
                for field in ["reps", "weight", "duration_secs", "distance", "is_warmup", "used_accessories", "band_color", "completed"]:
                    if field in data:
                        if field == "used_accessories":
                            setattr(set_row, field, normalize_accessory_list(data[field]))
                            continue
                        setattr(set_row, field, data[field])
                set_row.last_modified = now

            session.last_modified = now
            db.add(set_row)
            db.add(session)
            db.commit()
            events.append(("sessionUpdated", session.id))
            return SyncResponse(success=True, last_modified=session.last_modified)

        if action.action == "completeSession":
            session_id = data.get("id") or data.get("session_id")
            session = (
                db.query(WorkoutSession)
                .options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets))
                .filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id)
                .first()
            )
            if not session:
                return SyncResponse(success=False, error="Session not found")

            session.started_at = None
            session.finished_at = None
            session.duration_secs = None
            session.status = "completed"
            session.last_modified = time.time()
            detect_prs_for_session_completion(db, session)
            db.add(session)
            db.commit()
            events.append(("sessionCompleted", session.id))
            return SyncResponse(success=True, last_modified=session.last_modified)

        if action.action == "deleteSession":
            session_id = data.get("id")
            session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
            if not session:
                return SyncResponse(success=False, error="Session not found")
            db.delete(session)
            db.commit()
            events.append(("sessionUpdated", session_id))
            return SyncResponse(success=True, last_modified=time.time())

        return SyncResponse(success=False, error=f"Unsupported action: {action.action}")
    except Exception as exc:  # noqa: BLE001
        db.rollback()
        return SyncResponse(success=False, error=str(exc))


@router.get("/changes")
async def get_changes(
    since: float = Query(default=0),
    limit: int = Query(default=500, ge=1, le=2000),
    offset: int = Query(default=0, ge=0),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    return _collect_changes(db, user.id, _normalize_client_timestamp(since) or 0, limit, offset)


@router.post("/batch", response_model=BatchSyncResponse)
async def process_batch(
    payload: BatchSyncRequest,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> BatchSyncResponse:
    events: list[tuple[str, str | None]] = []
    results: list[SyncResponse] = []

    for action in payload.actions:
        result = await _process_sync_action(db, user, action, events)
        results.append(result)

    if events:
        await _broadcast_events(user.id, events)

    return BatchSyncResponse(results=results, server_timestamp=time.time())


@ws_router.websocket("/ws/sync")
async def sync_websocket(
    websocket: WebSocket,
    token: Optional[str] = Query(default=None),
) -> None:
    db = SessionLocal()
    user = get_user_from_ws_token(db, token)
    if not user:
        await websocket.close(code=1008)
        db.close()
        return

    await sync_notifier.connect(user.id, websocket)
    try:
        while True:
            message = await websocket.receive_text()
            if message.strip().lower() == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        await sync_notifier.disconnect(user.id, websocket)
        db.close()
