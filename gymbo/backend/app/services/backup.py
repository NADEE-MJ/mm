"""Automated JSON backup/export/import support."""

from __future__ import annotations

import json
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from app.schemas.exercises import normalize_string_list as normalize_accessory_list
from app.schemas.exercises import normalize_weight_type_int as normalize_weight_type
from models import (
    Exercise,
    SessionExercise,
    SessionSet,
    WeeklySchedule,
    WorkoutSession,
    WorkoutTemplate,
    WorkoutTemplateExercise,
    WorkoutType,
)
from sqlalchemy.orm import Session


class BackupManager:
    BACKUP_DIR = Path("backups")
    RETENTION_DAYS = 14

    def _user_backup_dir(self, user_id: str) -> Path:
        return self.BACKUP_DIR / user_id

    async def build_backup_payload(self, db: Session, user_id: str) -> dict[str, Any]:
        workout_types = db.query(WorkoutType).filter(WorkoutType.user_id == user_id).all()
        exercises = db.query(Exercise).filter(Exercise.user_id == user_id).all()
        templates = db.query(WorkoutTemplate).filter(WorkoutTemplate.user_id == user_id).all()
        template_ids = [template.id for template in templates]
        template_exercises = (
            db.query(WorkoutTemplateExercise)
            .filter(WorkoutTemplateExercise.template_id.in_(template_ids) if template_ids else False)
            .all()
        )
        schedule = db.query(WeeklySchedule).filter(WeeklySchedule.user_id == user_id).all()
        sessions = db.query(WorkoutSession).filter(WorkoutSession.user_id == user_id).all()
        session_ids = [session.id for session in sessions]
        session_exercises = (
            db.query(SessionExercise)
            .filter(SessionExercise.session_id.in_(session_ids) if session_ids else False)
            .all()
        )
        session_exercise_ids = [item.id for item in session_exercises]
        session_sets = (
            db.query(SessionSet)
            .filter(SessionSet.session_exercise_id.in_(session_exercise_ids) if session_exercise_ids else False)
            .all()
        )

        return {
            "version": 1,
            "user_id": user_id,
            "exported_at": time.time(),
            "workout_types": [
                {
                    "id": wt.id,
                    "name": wt.name,
                    "slug": wt.slug,
                    "icon": wt.icon,
                    "color": wt.color,
                    "is_system": wt.is_system,
                    "last_modified": wt.last_modified,
                }
                for wt in workout_types
            ],
            "exercises": [
                {
                    "id": ex.id,
                    "name": ex.name,
                    "description": ex.description,
                    "muscle_groups": ex.muscle_groups or 0,
                    "workout_type": ex.workout_type,
                    "weight_type": ex.weight_type,
                    "warmup_sets": ex.warmup_sets,
                    "accessories": ex.accessories or [],
                    "video_url": ex.video_url,
                    "goal_reps_min": ex.goal_reps_min,
                    "goal_reps_max": ex.goal_reps_max,
                    "show_highest_set": ex.show_highest_set,
                    "track_highest_set": ex.track_highest_set,
                    "highest_set_weight": ex.highest_set_weight,
                    "highest_set_reps": ex.highest_set_reps,
                    "show_one_rep_max": ex.show_one_rep_max,
                    "track_one_rep_max": ex.track_one_rep_max,
                    "one_rep_max": ex.one_rep_max,
                    "is_system": ex.is_system,
                    "source_exercise_id": ex.source_exercise_id,
                    "last_modified": ex.last_modified,
                }
                for ex in exercises
            ],
            "templates": [
                {
                    "id": t.id,
                    "name": t.name,
                    "description": t.description,
                    "workout_type_id": t.workout_type_id,
                    "is_system": t.is_system,
                    "created_at": t.created_at,
                    "last_modified": t.last_modified,
                }
                for t in templates
            ],
            "template_exercises": [
                {
                    "id": te.id,
                    "template_id": te.template_id,
                    "exercise_id": te.exercise_id,
                    "position": te.position,
                    "default_sets": te.default_sets,
                    "default_reps": te.default_reps,
                    "default_weight": te.default_weight,
                    "default_duration_secs": te.default_duration_secs,
                    "default_distance": te.default_distance,
                    "notes": te.notes,
                    "last_modified": te.last_modified,
                }
                for te in template_exercises
            ],
            "schedule": [
                {
                    "id": sch.id,
                    "day_of_week": sch.day_of_week,
                    "template_id": sch.template_id,
                    "last_modified": sch.last_modified,
                }
                for sch in schedule
            ],
            "sessions": [
                {
                    "id": s.id,
                    "template_id": s.template_id,
                    "date": s.date,
                    "started_at": s.started_at,
                    "finished_at": s.finished_at,
                    "duration_secs": s.duration_secs,
                    "notes": s.notes,
                    "status": s.status,
                    "last_modified": s.last_modified,
                }
                for s in sessions
            ],
            "session_exercises": [
                {
                    "id": se.id,
                    "session_id": se.session_id,
                    "exercise_id": se.exercise_id,
                    "position": se.position,
                    "notes": se.notes,
                    "last_modified": se.last_modified,
                }
                for se in session_exercises
            ],
            "session_sets": [
                {
                    "id": ss.id,
                    "session_exercise_id": ss.session_exercise_id,
                    "set_number": ss.set_number,
                    "reps": ss.reps,
                    "weight": ss.weight,
                    "duration_secs": ss.duration_secs,
                    "distance": ss.distance,
                    "is_warmup": ss.is_warmup,
                    "used_accessories": ss.used_accessories or [],
                    "band_color": ss.band_color,
                    "completed": ss.completed,
                    "last_modified": ss.last_modified,
                }
                for ss in session_sets
            ],
        }

    async def backup_user_data(self, db: Session, user_id: str) -> Path:
        payload = await self.build_backup_payload(db, user_id)
        backup_dir = self._user_backup_dir(user_id)
        backup_dir.mkdir(parents=True, exist_ok=True)

        backup_file = backup_dir / f"{datetime.now(timezone.utc).date().isoformat()}.json"
        backup_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        return backup_file

    def _parse_backup_stem(self, stem: str) -> datetime | None:
        for fmt in ("%Y-%m-%d", "%Y-%m-%d_%H"):
            try:
                return datetime.strptime(stem, fmt).replace(tzinfo=timezone.utc)
            except ValueError:
                continue
        return None

    async def cleanup_old_backups(self, user_id: str) -> None:
        backup_dir = self._user_backup_dir(user_id)
        if not backup_dir.exists():
            return

        cutoff = datetime.now(timezone.utc) - timedelta(days=self.RETENTION_DAYS)
        for backup_file in backup_dir.glob("*.json"):
            file_date = self._parse_backup_stem(backup_file.stem)
            if file_date and file_date < cutoff:
                backup_file.unlink(missing_ok=True)

    def list_backups(self, user_id: str) -> list[dict[str, Any]]:
        backup_dir = self._user_backup_dir(user_id)
        if not backup_dir.exists():
            return []

        backups: list[dict[str, Any]] = []
        for backup_file in backup_dir.glob("*.json"):
            stats = backup_file.stat()
            backups.append(
                {
                    "filename": backup_file.name,
                    "created_at": stats.st_mtime,
                    "size_bytes": stats.st_size,
                }
            )

        backups.sort(key=lambda item: item["created_at"], reverse=True)
        return backups

    def get_backup_file(self, user_id: str, filename: str) -> Path | None:
        if Path(filename).name != filename or not filename.endswith(".json"):
            return None

        backup_dir = self._user_backup_dir(user_id).resolve()
        candidate = (backup_dir / filename).resolve()
        if not candidate.is_relative_to(backup_dir):
            return None
        if not candidate.exists() or not candidate.is_file():
            return None
        return candidate

    async def restore_from_backup(
        self,
        db: Session,
        user_id: str,
        backup_file: Path | None = None,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        if payload is None:
            if not backup_file:
                raise ValueError("Either backup_file or payload must be provided")
            payload = json.loads(backup_file.read_text(encoding="utf-8"))

        # Replace user-owned data only; keep system data.
        db.query(SessionSet).filter(
            SessionSet.session_exercise_id.in_(
                db.query(SessionExercise.id)
                .join(WorkoutSession, WorkoutSession.id == SessionExercise.session_id)
                .filter(WorkoutSession.user_id == user_id)
            )
        ).delete(synchronize_session=False)
        db.query(SessionExercise).filter(
            SessionExercise.session_id.in_(
                db.query(WorkoutSession.id).filter(WorkoutSession.user_id == user_id)
            )
        ).delete(synchronize_session=False)
        db.query(WorkoutSession).filter(WorkoutSession.user_id == user_id).delete(synchronize_session=False)
        db.query(WeeklySchedule).filter(WeeklySchedule.user_id == user_id).delete(synchronize_session=False)
        db.query(WorkoutTemplateExercise).filter(
            WorkoutTemplateExercise.template_id.in_(
                db.query(WorkoutTemplate.id).filter(WorkoutTemplate.user_id == user_id)
            )
        ).delete(synchronize_session=False)
        db.query(WorkoutTemplate).filter(WorkoutTemplate.user_id == user_id).delete(synchronize_session=False)
        db.query(Exercise).filter(Exercise.user_id == user_id).delete(synchronize_session=False)
        db.query(WorkoutType).filter(WorkoutType.user_id == user_id).delete(synchronize_session=False)

        for wt in payload.get("workout_types", []):
            db.add(
                WorkoutType(
                    id=wt["id"],
                    user_id=user_id,
                    name=wt["name"],
                    slug=wt["slug"],
                    icon=wt.get("icon"),
                    color=wt.get("color"),
                    is_system=False,
                    last_modified=wt.get("last_modified") or time.time(),
                )
            )

        for ex in payload.get("exercises", []):
            weight_type = normalize_weight_type(ex.get("weight_type") or 4)
            db.add(
                Exercise(
                    id=ex["id"],
                    user_id=user_id,
                    name=ex["name"],
                    description=ex.get("description"),
                    muscle_groups=int(ex.get("muscle_groups") or 0),
                    workout_type=ex.get("workout_type"),
                    weight_type=weight_type,
                    warmup_sets=max(0, int(ex.get("warmup_sets") or 0)),
                    accessories=normalize_accessory_list(ex.get("accessories")),
                    video_url=ex.get("video_url"),
                    goal_reps_min=ex.get("goal_reps_min"),
                    goal_reps_max=ex.get("goal_reps_max"),
                    show_highest_set=bool(ex.get("show_highest_set", False)),
                    track_highest_set=bool(ex.get("track_highest_set", False)),
                    highest_set_weight=ex.get("highest_set_weight"),
                    highest_set_reps=ex.get("highest_set_reps"),
                    show_one_rep_max=bool(ex.get("show_one_rep_max", False)),
                    track_one_rep_max=bool(ex.get("track_one_rep_max", False)),
                    one_rep_max=ex.get("one_rep_max"),
                    is_system=False,
                    last_modified=ex.get("last_modified") or time.time(),
                )
            )

        for t in payload.get("templates", []):
            db.add(
                WorkoutTemplate(
                    id=t["id"],
                    user_id=user_id,
                    name=t["name"],
                    description=t.get("description"),
                    workout_type_id=t.get("workout_type_id"),
                    is_system=False,
                    created_at=t.get("created_at") or time.time(),
                    last_modified=t.get("last_modified") or time.time(),
                )
            )

        for te in payload.get("template_exercises", []):
            db.add(
                WorkoutTemplateExercise(
                    id=te["id"],
                    template_id=te["template_id"],
                    exercise_id=te["exercise_id"],
                    position=te.get("position") or 0,
                    default_sets=te.get("default_sets"),
                    default_reps=te.get("default_reps"),
                    default_weight=te.get("default_weight"),
                    default_duration_secs=te.get("default_duration_secs"),
                    default_distance=te.get("default_distance"),
                    notes=te.get("notes"),
                    last_modified=te.get("last_modified") or time.time(),
                )
            )

        for sch in payload.get("schedule", []):
            db.add(
                WeeklySchedule(
                    id=sch["id"],
                    user_id=user_id,
                    day_of_week=sch["day_of_week"],
                    template_id=sch.get("template_id"),
                    last_modified=sch.get("last_modified") or time.time(),
                )
            )

        for s in payload.get("sessions", []):
            db.add(
                WorkoutSession(
                    id=s["id"],
                    user_id=user_id,
                    template_id=s.get("template_id"),
                    date=s["date"],
                    started_at=s.get("started_at"),
                    finished_at=s.get("finished_at"),
                    duration_secs=s.get("duration_secs"),
                    notes=s.get("notes"),
                    status=s.get("status") or "in_progress",
                    last_modified=s.get("last_modified") or time.time(),
                )
            )

        for se in payload.get("session_exercises", []):
            db.add(
                SessionExercise(
                    id=se["id"],
                    session_id=se["session_id"],
                    exercise_id=se["exercise_id"],
                    position=se.get("position") or 0,
                    notes=se.get("notes"),
                    last_modified=se.get("last_modified") or time.time(),
                )
            )

        for ss in payload.get("session_sets", []):
            db.add(
                SessionSet(
                    id=ss["id"],
                    session_exercise_id=ss["session_exercise_id"],
                    set_number=ss.get("set_number") or 1,
                    reps=ss.get("reps"),
                    weight=ss.get("weight"),
                    duration_secs=ss.get("duration_secs"),
                    distance=ss.get("distance"),
                    is_warmup=bool(ss.get("is_warmup", False)),
                    used_accessories=normalize_accessory_list(ss.get("used_accessories")),
                    band_color=ss.get("band_color"),
                    completed=bool(ss.get("completed", False)),
                    last_modified=ss.get("last_modified") or time.time(),
                )
            )

        db.commit()
        return {"success": True}


backup_manager = BackupManager()
