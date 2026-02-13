"""Automated JSON backup/export/import support."""

from __future__ import annotations

import json
import logging
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from app.services.movies import serialize_movie
from models import CustomList, Movie, MovieStatus, Person, Recommendation, User, WatchHistory
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def _normalize_vote_type(value: object) -> bool:
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    return text in {"upvote", "1", "true", "t", "yes"}


class BackupManager:
    """Handles automated per-user backups and restores."""

    BACKUP_DIR = Path("backups")
    RETENTION_DAYS = 30

    def _user_backup_dir(self, user_id: str) -> Path:
        return self.BACKUP_DIR / user_id

    async def build_backup_payload(self, db: Session, user_id: str) -> dict[str, Any]:
        movies = db.query(Movie).filter(Movie.user_id == user_id).all()
        people = db.query(Person).filter(Person.user_id == user_id).all()
        lists = db.query(CustomList).filter(CustomList.user_id == user_id).all()

        return {
            "version": 1,
            "user_id": user_id,
            "exported_at": time.time(),
            "movies": [serialize_movie(movie) for movie in movies],
            "people": [
                {
                    "id": person.id,
                    "name": person.name,
                    "user_id": person.user_id,
                    "is_trusted": person.is_trusted,
                    "color": person.color,
                    "emoji": person.emoji,
                    "last_modified": person.last_modified,
                }
                for person in people
            ],
            "lists": [
                {
                    "id": custom_list.id,
                    "user_id": custom_list.user_id,
                    "name": custom_list.name,
                    "color": custom_list.color,
                    "icon": custom_list.icon,
                    "position": custom_list.position,
                    "created_at": custom_list.created_at,
                    "last_modified": custom_list.last_modified,
                }
                for custom_list in lists
            ],
        }

    async def backup_user_data(self, db: Session, user_id: str) -> Path:
        """Write a full JSON snapshot for one user."""
        payload = await self.build_backup_payload(db, user_id)
        backup_dir = self._user_backup_dir(user_id)
        backup_dir.mkdir(parents=True, exist_ok=True)

        backup_file = backup_dir / f"{datetime.now(timezone.utc).date().isoformat()}.json"
        backup_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        return backup_file

    async def cleanup_old_backups(self, user_id: str) -> None:
        """Remove backups older than retention window."""
        backup_dir = self._user_backup_dir(user_id)
        if not backup_dir.exists():
            return

        cutoff = datetime.now(timezone.utc) - timedelta(days=self.RETENTION_DAYS)
        for backup_file in backup_dir.glob("*.json"):
            try:
                date_text = backup_file.stem
                file_date = datetime.fromisoformat(date_text).replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            if file_date < cutoff:
                backup_file.unlink(missing_ok=True)

    async def restore_from_backup(
        self,
        db: Session,
        user_id: str,
        backup_file: Path | None = None,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Restore user data from backup JSON."""
        if payload is None:
            if not backup_file:
                raise ValueError("Either backup_file or payload must be provided")
            payload = json.loads(backup_file.read_text(encoding="utf-8"))

        imported_counts = {"movies": 0, "people": 0, "lists": 0}
        errors: list[str] = []

        try:
            for person_data in payload.get("people", []):
                name = person_data.get("name")
                if not name:
                    continue
                incoming_last_modified = float(person_data.get("last_modified") or time.time())
                existing = (
                    db.query(Person)
                    .filter(Person.name == name, Person.user_id == user_id)
                    .first()
                )
                if existing and (existing.last_modified or 0) > incoming_last_modified:
                    continue

                if not existing:
                    existing = Person(name=name, user_id=user_id)
                    db.add(existing)
                existing.is_trusted = person_data.get("is_trusted", False)
                existing.color = person_data.get("color") or "#0a84ff"
                existing.emoji = person_data.get("emoji")
                existing.last_modified = incoming_last_modified
                imported_counts["people"] += 1

            for list_data in payload.get("lists", []):
                list_id = list_data.get("id")
                if not list_id:
                    continue
                incoming_last_modified = float(list_data.get("last_modified") or time.time())
                existing = (
                    db.query(CustomList)
                    .filter(CustomList.id == list_id, CustomList.user_id == user_id)
                    .first()
                )
                if existing and (existing.last_modified or 0) > incoming_last_modified:
                    continue

                if not existing:
                    existing = CustomList(id=list_id, user_id=user_id, name=list_data.get("name", "Imported"))
                    db.add(existing)
                existing.name = list_data.get("name", existing.name)
                existing.color = list_data.get("color", "#0a84ff")
                existing.icon = list_data.get("icon", "list")
                existing.position = int(list_data.get("position", 0))
                existing.created_at = float(list_data.get("created_at") or time.time())
                existing.last_modified = incoming_last_modified
                imported_counts["lists"] += 1

            for movie_data in payload.get("movies", []):
                imdb_id = movie_data.get("imdb_id")
                if not imdb_id:
                    continue
                incoming_last_modified = float(movie_data.get("last_modified") or time.time())
                existing_movie = (
                    db.query(Movie)
                    .filter(Movie.imdb_id == imdb_id, Movie.user_id == user_id)
                    .first()
                )
                if existing_movie and (existing_movie.last_modified or 0) > incoming_last_modified:
                    continue

                if not existing_movie:
                    existing_movie = Movie(imdb_id=imdb_id, user_id=user_id)
                    db.add(existing_movie)
                existing_movie.tmdb_data = json.dumps(movie_data.get("tmdb_data")) if movie_data.get("tmdb_data") else None
                existing_movie.omdb_data = json.dumps(movie_data.get("omdb_data")) if movie_data.get("omdb_data") else None
                existing_movie.last_modified = incoming_last_modified

                db.query(Recommendation).filter(
                    Recommendation.imdb_id == imdb_id,
                    Recommendation.user_id == user_id,
                ).delete()
                for rec in movie_data.get("recommendations", []):
                    rec_person_id = rec.get("person_id")
                    person_name = rec.get("person_name") or rec.get("person")

                    person = None
                    if isinstance(rec_person_id, int):
                        person = (
                            db.query(Person)
                            .filter(Person.id == rec_person_id, Person.user_id == user_id)
                            .first()
                        )
                    if not person and person_name:
                        person = (
                            db.query(Person)
                            .filter(Person.name == person_name, Person.user_id == user_id)
                            .first()
                        )
                    if not person and person_name:
                        person = Person(
                            name=person_name,
                            user_id=user_id,
                            is_trusted=False,
                            color="#0a84ff",
                        )
                        db.add(person)
                        db.flush()
                    if not person:
                        continue
                    db.add(
                        Recommendation(
                            imdb_id=imdb_id,
                            user_id=user_id,
                            person_id=person.id,
                            date_recommended=float(rec.get("date_recommended") or time.time()),
                            vote_type=_normalize_vote_type(rec.get("vote_type", True)),
                        )
                    )

                watch_history_data = movie_data.get("watch_history")
                existing_watch = (
                    db.query(WatchHistory)
                    .filter(WatchHistory.imdb_id == imdb_id, WatchHistory.user_id == user_id)
                    .first()
                )
                if watch_history_data:
                    if not existing_watch:
                        existing_watch = WatchHistory(imdb_id=imdb_id, user_id=user_id, date_watched=time.time(), my_rating=5.0)
                        db.add(existing_watch)
                    existing_watch.date_watched = float(watch_history_data.get("date_watched") or time.time())
                    existing_watch.my_rating = float(watch_history_data.get("my_rating") or 5.0)
                elif existing_watch:
                    db.delete(existing_watch)

                movie_status = (
                    db.query(MovieStatus)
                    .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user_id)
                    .first()
                )
                if not movie_status:
                    movie_status = MovieStatus(imdb_id=imdb_id, user_id=user_id, status="toWatch")
                    db.add(movie_status)
                movie_status.status = movie_data.get("status", "toWatch")
                movie_status.custom_list_id = movie_data.get("custom_list_id")

                imported_counts["movies"] += 1

            db.commit()

        except Exception as exc:  # noqa: BLE001
            db.rollback()
            errors.append(str(exc))

        return {
            "success": len(errors) == 0,
            "imported_counts": imported_counts,
            "errors": errors,
        }

    async def run_daily_backups(self, db: Session) -> None:
        """Execute daily backups for every user."""
        users = db.query(User).all()
        for user in users:
            try:
                await self.backup_user_data(db, user.id)
                await self.cleanup_old_backups(user.id)
            except Exception as exc:  # noqa: BLE001
                logger.error("Daily backup failed for user=%s: %s", user.id, exc)


backup_manager = BackupManager()
