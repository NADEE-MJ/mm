"""Sync endpoints and WebSocket notifications."""

from __future__ import annotations

import logging
import time
import uuid
from typing import Optional

from app.schemas.sync import (
    BatchSyncRequest,
    BatchSyncResponse,
    SyncAction,
    SyncResponse,
)
from app.services.conflict_resolver import ConflictResolver
from app.services.movies import (
    get_or_create_movie,
    get_or_create_movie_with_state,
    serialize_movie,
)
from app.services.notifications import (
    notify_list_updated,
    notify_movie_added,
    notify_movie_change,
    notify_movie_deleted,
    notify_people_change,
    sync_notifier,
)
from app.services.security import get_user_from_ws_token
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from models import (
    CustomList,
    Movie,
    MovieStatus,
    Person,
    Recommendation,
    User,
    WatchHistory,
)
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["sync"])
ws_router = APIRouter(tags=["sync"])


def _normalize_client_timestamp(value: float | None) -> float | None:
    if value is None:
        return None
    # Most clients send ms since epoch; accept second timestamps too.
    return value / 1000.0 if value > 10_000_000_000 else value


def _person_payload(person: Person) -> dict:
    return {
        "name": person.name,
        "user_id": person.user_id,
        "is_trusted": person.is_trusted,
        "is_default": person.is_default,
        "color": person.color,
        "emoji": person.emoji,
        "last_modified": person.last_modified,
    }


def _list_payload(custom_list: CustomList) -> dict:
    return {
        "id": custom_list.id,
        "user_id": custom_list.user_id,
        "name": custom_list.name,
        "color": custom_list.color,
        "icon": custom_list.icon,
        "position": custom_list.position,
        "created_at": custom_list.created_at,
        "last_modified": custom_list.last_modified,
    }


def _collect_changes(
    db: Session,
    user_id: str,
    since: float,
    limit: int,
    offset: int,
) -> dict:
    if since <= 0:
        movies = db.query(Movie).filter(Movie.user_id == user_id).all()
        people = db.query(Person).filter(Person.user_id == user_id).all()
        lists = db.query(CustomList).filter(CustomList.user_id == user_id).all()
    else:
        movies = (
            db.query(Movie)
            .filter(Movie.user_id == user_id, Movie.last_modified >= since)
            .all()
        )
        people = (
            db.query(Person)
            .filter(Person.user_id == user_id, Person.last_modified >= since)
            .all()
        )
        lists = (
            db.query(CustomList)
            .filter(CustomList.user_id == user_id, CustomList.last_modified >= since)
            .all()
        )

    change_rows: list[tuple[str, float, object]] = []
    change_rows.extend(("movie", movie.last_modified or 0.0, movie) for movie in movies)
    change_rows.extend(("person", person.last_modified or 0.0, person) for person in people)
    change_rows.extend(("list", custom_list.last_modified or 0.0, custom_list) for custom_list in lists)
    change_rows.sort(key=lambda row: row[1])

    total = len(change_rows)
    selected = change_rows[offset : offset + limit]

    movie_payload: list[dict] = []
    people_payload: list[dict] = []
    lists_payload: list[dict] = []
    deleted_movie_ids: list[str] = []

    for kind, _changed_at, entity in selected:
        if kind == "movie":
            movie = entity
            movie_payload.append(serialize_movie(movie))
            movie_status = movie.status.status if movie.status else None
            if movie_status == "deleted":
                deleted_movie_ids.append(movie.imdb_id)
        elif kind == "person":
            people_payload.append(_person_payload(entity))
        elif kind == "list":
            lists_payload.append(_list_payload(entity))

    has_more = (offset + limit) < total
    return {
        "movies": movie_payload,
        "people": people_payload,
        "lists": lists_payload,
        "deleted_movie_ids": deleted_movie_ids,
        "has_more": has_more,
        "next_offset": (offset + limit) if has_more else None,
        "server_timestamp": time.time(),
    }


async def _broadcast_events(user_id: str, events: list[tuple[str, str | None]]) -> None:
    movie_added_ids = sorted({entity_id for event, entity_id in events if event == "movieAdded" and entity_id})
    movie_updated_ids = sorted({entity_id for event, entity_id in events if event == "movieUpdated" and entity_id})
    movie_deleted_ids = sorted({entity_id for event, entity_id in events if event == "movieDeleted" and entity_id})
    list_ids = sorted({entity_id for event, entity_id in events if event == "listUpdated" and entity_id})
    people_changed = any(event == "peopleUpdated" for event, _ in events)

    for imdb_id in movie_added_ids:
        await notify_movie_added(user_id, imdb_id)
    for imdb_id in movie_updated_ids:
        await notify_movie_change(user_id, imdb_id)
    for imdb_id in movie_deleted_ids:
        await notify_movie_deleted(user_id, imdb_id)
    if people_changed:
        await notify_people_change(user_id)
    for list_id in list_ids:
        await notify_list_updated(user_id, list_id)


async def _process_sync_action(
    action: SyncAction,
    user: User,
    db: Session,
) -> tuple[SyncResponse, list[tuple[str, str | None]]]:
    action_type = action.action
    data = action.data
    client_timestamp = _normalize_client_timestamp(action.timestamp)
    emitted_events: list[tuple[str, str | None]] = []

    try:
        if action_type == "addRecommendation":
            imdb_id = data.get("imdb_id")
            if not imdb_id:
                return SyncResponse(success=False, error="Missing imdb_id"), emitted_events

            person_name = data.get("person")
            movie, created = get_or_create_movie_with_state(
                db,
                user.id,
                imdb_id,
                data.get("tmdb_data"),
                data.get("omdb_data"),
            )

            created_person = False
            if person_name:
                existing = (
                    db.query(Recommendation)
                    .filter(
                        Recommendation.imdb_id == imdb_id,
                        Recommendation.user_id == user.id,
                        Recommendation.person == person_name,
                    )
                    .first()
                )

                if existing:
                    existing.vote_type = data.get("vote_type", "upvote")
                    existing.date_recommended = data.get("date_recommended", time.time())
                else:
                    recommendation = Recommendation(
                        imdb_id=imdb_id,
                        user_id=user.id,
                        person=person_name,
                        date_recommended=data.get("date_recommended", time.time()),
                        vote_type=data.get("vote_type", "upvote"),
                    )
                    db.add(recommendation)

                    person_obj = (
                        db.query(Person)
                        .filter(Person.name == person_name, Person.user_id == user.id)
                        .first()
                    )
                    if not person_obj:
                        db.add(Person(name=person_name, user_id=user.id, is_trusted=False))
                        created_person = True

            movie.last_modified = time.time()
            db.commit()

            emitted_events.append(("movieAdded", imdb_id) if created else ("movieUpdated", imdb_id))
            if created_person:
                emitted_events.append(("peopleUpdated", None))

            return SyncResponse(success=True, last_modified=movie.last_modified), emitted_events

        if action_type == "removeRecommendation":
            imdb_id = data.get("imdb_id")
            person_name = data.get("person")
            if not imdb_id or not person_name:
                return SyncResponse(success=False, error="Missing imdb_id/person"), emitted_events

            recommendation = (
                db.query(Recommendation)
                .filter(
                    Recommendation.imdb_id == imdb_id,
                    Recommendation.user_id == user.id,
                    Recommendation.person == person_name,
                )
                .first()
            )
            if recommendation:
                db.delete(recommendation)
                movie = (
                    db.query(Movie)
                    .filter(Movie.imdb_id == imdb_id, Movie.user_id == user.id)
                    .first()
                )
                if movie:
                    movie.last_modified = time.time()
                    db.commit()
                    emitted_events.append(("movieUpdated", imdb_id))
                    return SyncResponse(success=True, last_modified=movie.last_modified), emitted_events
                db.commit()
            return SyncResponse(success=True, last_modified=time.time()), emitted_events

        if action_type == "updateRecommendationVote":
            imdb_id = data.get("imdb_id")
            person_name = data.get("person")
            vote_type = data.get("vote_type", "upvote")
            if not imdb_id or not person_name:
                return SyncResponse(success=False, error="Missing imdb_id/person"), emitted_events

            movie = get_or_create_movie(db, user.id, imdb_id)
            conflict = ConflictResolver.check_conflict(movie, client_timestamp, serialize_movie)
            if conflict:
                return SyncResponse(
                    success=False,
                    conflict=True,
                    error="Conflict: server has a newer version of this movie",
                    last_modified=conflict["server_last_modified"],
                    server_state=conflict.get("server_state"),
                ), emitted_events

            recommendation = (
                db.query(Recommendation)
                .filter(
                    Recommendation.imdb_id == imdb_id,
                    Recommendation.user_id == user.id,
                    Recommendation.person == person_name,
                )
                .first()
            )
            if recommendation:
                recommendation.vote_type = vote_type
                recommendation.date_recommended = data.get("date_recommended", time.time())
                movie.last_modified = time.time()
                db.commit()
                emitted_events.append(("movieUpdated", imdb_id))
                return SyncResponse(success=True, last_modified=movie.last_modified), emitted_events
            db.rollback()
            return SyncResponse(success=False, error="Recommendation not found"), emitted_events

        if action_type == "markWatched":
            imdb_id = data.get("imdb_id")
            if not imdb_id:
                return SyncResponse(success=False, error="Missing imdb_id"), emitted_events
            movie, created = get_or_create_movie_with_state(db, user.id, imdb_id)

            conflict = ConflictResolver.check_conflict(movie, client_timestamp, serialize_movie)
            if conflict:
                return SyncResponse(
                    success=False,
                    conflict=True,
                    error="Conflict: server has a newer version of this movie",
                    last_modified=conflict["server_last_modified"],
                    server_state=conflict.get("server_state"),
                ), emitted_events

            existing = (
                db.query(WatchHistory)
                .filter(
                    WatchHistory.imdb_id == imdb_id,
                    WatchHistory.user_id == user.id,
                )
                .first()
            )
            if existing:
                existing.date_watched = data.get("date_watched", time.time())
                existing.my_rating = data.get("my_rating", data.get("rating"))
            else:
                db.add(
                    WatchHistory(
                        imdb_id=imdb_id,
                        user_id=user.id,
                        date_watched=data.get("date_watched", time.time()),
                        my_rating=data.get("my_rating", data.get("rating")),
                    )
                )

            movie_status = (
                db.query(MovieStatus)
                .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
                .first()
            )
            if movie_status:
                movie_status.status = "watched"
            else:
                db.add(MovieStatus(imdb_id=imdb_id, user_id=user.id, status="watched"))

            movie.last_modified = time.time()
            db.commit()
            emitted_events.append(("movieAdded", imdb_id) if created else ("movieUpdated", imdb_id))
            return SyncResponse(success=True, last_modified=movie.last_modified), emitted_events

        if action_type == "updateRating":
            imdb_id = data.get("imdb_id")
            if not imdb_id:
                return SyncResponse(success=False, error="Missing imdb_id"), emitted_events
            movie = get_or_create_movie(db, user.id, imdb_id)

            conflict = ConflictResolver.check_conflict(movie, client_timestamp, serialize_movie)
            if conflict:
                return SyncResponse(
                    success=False,
                    conflict=True,
                    error="Conflict: server has a newer version of this movie",
                    last_modified=conflict["server_last_modified"],
                    server_state=conflict.get("server_state"),
                ), emitted_events

            watch = (
                db.query(WatchHistory)
                .filter(WatchHistory.imdb_id == imdb_id, WatchHistory.user_id == user.id)
                .first()
            )
            if not watch:
                return SyncResponse(success=False, error="Watch history not found"), emitted_events

            watch.my_rating = data.get("my_rating", data.get("rating"))
            movie.last_modified = time.time()
            db.commit()
            emitted_events.append(("movieUpdated", imdb_id))
            return SyncResponse(success=True, last_modified=movie.last_modified), emitted_events

        if action_type == "updateStatus":
            imdb_id = data.get("imdb_id")
            new_status = data.get("status")
            if not imdb_id or not new_status:
                return SyncResponse(success=False, error="Missing imdb_id/status"), emitted_events

            movie, created = get_or_create_movie_with_state(db, user.id, imdb_id)

            conflict = ConflictResolver.check_conflict(movie, client_timestamp, serialize_movie)
            if conflict:
                return SyncResponse(
                    success=False,
                    conflict=True,
                    error="Conflict: server has a newer version of this movie",
                    last_modified=conflict["server_last_modified"],
                    server_state=conflict.get("server_state"),
                ), emitted_events

            movie_status = (
                db.query(MovieStatus)
                .filter(MovieStatus.imdb_id == imdb_id, MovieStatus.user_id == user.id)
                .first()
            )
            if movie_status:
                movie_status.status = new_status
                movie_status.custom_list_id = data.get("custom_list_id") if new_status == "custom" else None
            else:
                db.add(
                    MovieStatus(
                        imdb_id=imdb_id,
                        user_id=user.id,
                        status=new_status,
                        custom_list_id=data.get("custom_list_id") if new_status == "custom" else None,
                    )
                )

            movie.last_modified = time.time()
            db.commit()

            if new_status == "deleted":
                emitted_events.append(("movieDeleted", imdb_id))
            else:
                emitted_events.append(("movieAdded", imdb_id) if created else ("movieUpdated", imdb_id))
            return SyncResponse(success=True, last_modified=movie.last_modified), emitted_events

        if action_type == "addPerson":
            name = data.get("name")
            if not name:
                return SyncResponse(success=False, error="Missing person name"), emitted_events

            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if not person:
                db.add(
                    Person(
                        name=name,
                        user_id=user.id,
                        is_trusted=data.get("is_trusted", False),
                        is_default=data.get("is_default", False),
                        color=data.get("color") or "#0a84ff",
                        emoji=data.get("emoji"),
                    )
                )
                db.commit()
                emitted_events.append(("peopleUpdated", None))
            return SyncResponse(success=True, last_modified=time.time()), emitted_events

        if action_type in {"updatePerson", "updatePersonTrust"}:
            name = data.get("name")
            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if not person:
                return SyncResponse(success=False, error="Person not found"), emitted_events

            if action_type == "updatePersonTrust":
                person.is_trusted = data.get("is_trusted")
            else:
                if "is_trusted" in data:
                    person.is_trusted = data.get("is_trusted")
                if "is_default" in data:
                    person.is_default = data.get("is_default")
                if "color" in data:
                    person.color = data.get("color")
                if "emoji" in data:
                    person.emoji = data.get("emoji")

            person.last_modified = time.time()
            db.commit()
            emitted_events.append(("peopleUpdated", None))
            return SyncResponse(success=True, last_modified=person.last_modified), emitted_events

        if action_type == "deletePerson":
            name = data.get("name")
            person = (
                db.query(Person)
                .filter(Person.name == name, Person.user_id == user.id)
                .first()
            )
            if person:
                db.delete(person)
                db.commit()
                emitted_events.append(("peopleUpdated", None))
            return SyncResponse(success=True, last_modified=time.time()), emitted_events

        if action_type == "addList":
            list_id = data.get("id") or str(uuid.uuid4())
            custom_list = (
                db.query(CustomList)
                .filter(CustomList.id == list_id, CustomList.user_id == user.id)
                .first()
            )
            if custom_list:
                custom_list.name = data.get("name", custom_list.name)
                custom_list.color = data.get("color", custom_list.color)
                custom_list.icon = data.get("icon", custom_list.icon)
                custom_list.position = data.get("position", custom_list.position)
            else:
                custom_list = CustomList(
                    id=list_id,
                    user_id=user.id,
                    name=data.get("name", "New List"),
                    color=data.get("color") or "#0a84ff",
                    icon=data.get("icon") or "list",
                    position=data.get("position", 0),
                )
                db.add(custom_list)
            custom_list.last_modified = time.time()
            db.commit()
            emitted_events.append(("listUpdated", list_id))
            return SyncResponse(success=True, last_modified=custom_list.last_modified), emitted_events

        if action_type == "updateList":
            list_id = data.get("id")
            custom_list = (
                db.query(CustomList)
                .filter(CustomList.id == list_id, CustomList.user_id == user.id)
                .first()
            )
            if not custom_list:
                return SyncResponse(success=False, error="List not found"), emitted_events

            if "name" in data:
                custom_list.name = data.get("name")
            if "color" in data:
                custom_list.color = data.get("color")
            if "icon" in data:
                custom_list.icon = data.get("icon")
            if "position" in data:
                custom_list.position = data.get("position")
            custom_list.last_modified = time.time()
            db.commit()
            emitted_events.append(("listUpdated", list_id))
            return SyncResponse(success=True, last_modified=custom_list.last_modified), emitted_events

        if action_type == "deleteList":
            list_id = data.get("id")
            custom_list = (
                db.query(CustomList)
                .filter(CustomList.id == list_id, CustomList.user_id == user.id)
                .first()
            )
            if custom_list:
                db.query(MovieStatus).filter(
                    MovieStatus.custom_list_id == list_id,
                    MovieStatus.user_id == user.id,
                ).update({"status": "toWatch", "custom_list_id": None})
                db.delete(custom_list)
                db.commit()
                emitted_events.append(("listUpdated", list_id))
            return SyncResponse(success=True, last_modified=time.time()), emitted_events

        return SyncResponse(success=False, error=f"Unknown action type: {action_type}"), emitted_events

    except Exception as exc:  # noqa: BLE001
        db.rollback()
        logger.error("Sync action failed for user=%s action=%s: %s", user.id, action_type, exc)
        return SyncResponse(success=False, error=str(exc)), emitted_events


@router.get("")
async def sync_get_changes_legacy(
    since: float = 0,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Backward-compatible sync endpoint used by older clients."""
    payload = _collect_changes(db=db, user_id=user.id, since=since, limit=10_000, offset=0)
    payload["timestamp"] = payload["server_timestamp"]
    return payload


@router.get("/changes")
async def sync_get_changes(
    since: float = 0,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Return incremental changes since a timestamp with pagination."""
    return _collect_changes(db=db, user_id=user.id, since=since, limit=limit, offset=offset)


@router.post("", response_model=SyncResponse)
async def sync_process_action(
    action: SyncAction,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Process one sync action (legacy single-action endpoint)."""
    response, events = await _process_sync_action(action, user, db)
    if response.success and events:
        await _broadcast_events(user.id, events)
    return response


@router.post("/batch", response_model=BatchSyncResponse)
async def sync_batch(
    request: BatchSyncRequest,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
):
    """Process a batch of sync actions sequentially and return per-item results."""
    results: list[SyncResponse] = []
    aggregated_events: list[tuple[str, str | None]] = []

    for action in request.actions:
        result, events = await _process_sync_action(action, user, db)
        results.append(result)
        if result.success and events:
            aggregated_events.extend(events)

    if aggregated_events:
        await _broadcast_events(user.id, aggregated_events)

    return BatchSyncResponse(results=results, server_timestamp=time.time())


@ws_router.websocket("/ws/sync")
async def sync_websocket_endpoint(
    websocket: WebSocket,
    token: Optional[str] = Query(None),
):
    """WebSocket endpoint that pushes change notifications in real time."""
    # Don't use Depends(get_db) for WebSocket - manually manage the session.
    from database import SessionLocal

    db = SessionLocal()
    try:
        user = get_user_from_ws_token(db, token)
    finally:
        db.close()

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
