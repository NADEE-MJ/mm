"""Sync endpoints and WebSocket notifications."""

from __future__ import annotations

import logging
import time
from typing import Optional

from auth import get_required_user
from app.schemas.sync import SyncAction, SyncResponse
from app.services.movies import get_or_create_movie, serialize_movie
from app.services.notifications import (
    notify_movie_change,
    notify_people_change,
    sync_notifier,
)
from app.services.security import get_user_from_ws_token
from database import get_db
from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from models import Movie, MovieStatus, Person, Recommendation, User, WatchHistory
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["sync"])
ws_router = APIRouter(tags=["sync"])


@router.get("")
async def sync_get_changes(
    since: float = 0,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Return all movie & people changes after a timestamp."""
    movies = (
        db.query(Movie)
        .filter(Movie.user_id == user.id, Movie.last_modified > since)
        .all()
    )
    movie_payload = [serialize_movie(movie) for movie in movies]

    people = db.query(Person).filter(Person.user_id == user.id).all()
    people_payload = [
        {
            "name": p.name,
            "is_trusted": p.is_trusted,
            "is_default": p.is_default,
            "color": p.color,
            "emoji": p.emoji,
        }
        for p in people
    ]

    return {"movies": movie_payload, "people": people_payload, "timestamp": time.time()}


@router.post("", response_model=SyncResponse)
async def sync_process_action(
    action: SyncAction,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Process a queued sync action sent from the client."""
    try:
        action_type = action.action
        data = action.data
        client_timestamp = action.timestamp / 1000 if action.timestamp else None

        def conflict_response(movie_obj: Movie, message: str) -> SyncResponse:
            return SyncResponse(
                success=False,
                conflict=True,
                error=message,
                last_modified=movie_obj.last_modified,
                server_state=serialize_movie(movie_obj),
            )

        if action_type == "addRecommendation":
            imdb_id = data.get("imdb_id")
            person_name = data.get("person")
            movie = get_or_create_movie(
                db, user.id, imdb_id, data.get("tmdb_data"), data.get("omdb_data")
            )

            existing = (
                db.query(Recommendation)
                .filter(
                    Recommendation.imdb_id == imdb_id,
                    Recommendation.user_id == user.id,
                    Recommendation.person == person_name,
                )
                .first()
            )

            created_person = False

            if not existing:
                recommendation = Recommendation(
                    imdb_id=imdb_id,
                    user_id=user.id,
                    person=person_name,
                    date_recommended=data.get("date_recommended", time.time()),
                )
                db.add(recommendation)

                person_obj = (
                    db.query(Person)
                    .filter(Person.name == person_name, Person.user_id == user.id)
                    .first()
                )
                if not person_obj:
                    person_obj = Person(name=person_name, user_id=user.id, is_trusted=False)
                    db.add(person_obj)
                    created_person = True

            movie.last_modified = time.time()
            db.commit()

            await notify_movie_change(user.id, imdb_id)
            if created_person:
                await notify_people_change(user.id)

            return SyncResponse(success=True, last_modified=movie.last_modified)

        if action_type == "markWatched":
            imdb_id = data.get("imdb_id")
            movie = get_or_create_movie(db, user.id, imdb_id)

            if (
                movie.last_modified
                and client_timestamp is not None
                and client_timestamp < movie.last_modified
            ):
                return conflict_response(
                    movie, "Conflict: server has a newer version of this movie"
                )

            existing = (
                db.query(WatchHistory)
                .filter(
                    WatchHistory.imdb_id == imdb_id, WatchHistory.user_id == user.id
                )
                .first()
            )
            if existing:
                existing.date_watched = data.get("date_watched")
                existing.my_rating = data.get("my_rating")
            else:
                db_watch = WatchHistory(
                    imdb_id=imdb_id,
                    user_id=user.id,
                    date_watched=data.get("date_watched"),
                    my_rating=data.get("my_rating"),
                )
                db.add(db_watch)

            movie_status = (
                db.query(MovieStatus)
                .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
                .first()
            )
            if movie_status:
                movie_status.status = "watched"
            else:
                movie_status = MovieStatus(
                    imdb_id=imdb_id, user_id=user.id, status="watched"
                )
                db.add(movie_status)

            movie.last_modified = time.time()
            db.commit()

            await notify_movie_change(user.id, imdb_id)

            return SyncResponse(success=True, last_modified=movie.last_modified)

        if action_type == "updateStatus":
            imdb_id = data.get("imdb_id")
            new_status = data.get("status")
            movie = get_or_create_movie(db, user.id, imdb_id)

            if (
                movie.last_modified
                and client_timestamp is not None
                and client_timestamp < movie.last_modified
            ):
                return conflict_response(
                    movie, "Conflict: server has a newer version of this movie"
                )

            movie_status = (
                db.query(MovieStatus)
                .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
                .first()
            )
            if movie_status:
                movie_status.status = new_status
            else:
                movie_status = MovieStatus(
                    imdb_id=imdb_id, user_id=user.id, status=new_status
                )
                db.add(movie_status)

            movie.last_modified = time.time()
            db.commit()

            await notify_movie_change(user.id, imdb_id)

            return SyncResponse(success=True, last_modified=movie.last_modified)

        if action_type == "addPerson":
            name = data.get("name")
            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if not person:
                person = Person(
                    name=name,
                    user_id=user.id,
                    is_trusted=data.get("is_trusted", False),
                    is_default=data.get("is_default", False),
                    color=data.get("color") or "#0a84ff",
                    emoji=data.get("emoji"),
                )
                db.add(person)
                db.commit()
                await notify_people_change(user.id)

            return SyncResponse(success=True, last_modified=time.time())

        if action_type in {"updatePerson", "updatePersonTrust"}:
            name = data.get("name")
            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if person:
                if action_type == "updatePersonTrust":
                    person.is_trusted = data.get("is_trusted")
                else:
                    if "is_trusted" in data:
                        person.is_trusted = data.get("is_trusted")
                    if "color" in data:
                        person.color = data.get("color")
                    if "emoji" in data:
                        person.emoji = data.get("emoji")
                    if "is_default" in data:
                        person.is_default = data.get("is_default")
                db.commit()
                await notify_people_change(user.id)

            return SyncResponse(success=True, last_modified=time.time())

        return SyncResponse(success=False, error=f"Unknown action type: {action_type}")

    except Exception as exc:  # noqa: BLE001
        db.rollback()
        logger.error("Sync action failed: %s", exc)
        return SyncResponse(success=False, error=str(exc))


@ws_router.websocket("/ws/sync")
async def sync_websocket_endpoint(
    websocket: WebSocket,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """WebSocket endpoint that pushes change notifications in real time."""
    user = get_user_from_ws_token(db, token)
    if not user:
        await websocket.close(code=1008)
        return

    await sync_notifier.connect(user.id, websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        sync_notifier.disconnect(user.id, websocket)
    except Exception:  # noqa: BLE001
        sync_notifier.disconnect(user.id, websocket)
