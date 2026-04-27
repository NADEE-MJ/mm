"""WebSocket connection manager and event helpers."""

from __future__ import annotations

import asyncio
from collections import defaultdict

from fastapi import WebSocket


class SyncNotifier:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[user_id].add(websocket)

    async def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            if user_id in self._connections:
                self._connections[user_id].discard(websocket)
                if not self._connections[user_id]:
                    self._connections.pop(user_id, None)

    async def notify(self, user_id: str, event_type: str, payload: dict | None = None) -> None:
        message = {"type": event_type, "payload": payload or {}}
        async with self._lock:
            clients = list(self._connections.get(user_id, set()))

        stale: list[WebSocket] = []
        for ws in clients:
            try:
                await ws.send_json(message)
            except Exception:  # noqa: BLE001
                stale.append(ws)

        if stale:
            async with self._lock:
                for ws in stale:
                    self._connections[user_id].discard(ws)
                if user_id in self._connections and not self._connections[user_id]:
                    self._connections.pop(user_id, None)


sync_notifier = SyncNotifier()


async def notify_session_updated(user_id: str, session_id: str) -> None:
    await sync_notifier.notify(user_id, "sessionUpdated", {"session_id": session_id})


async def notify_session_completed(user_id: str, session_id: str) -> None:
    await sync_notifier.notify(user_id, "sessionCompleted", {"session_id": session_id})


async def notify_template_updated(user_id: str, template_id: str) -> None:
    await sync_notifier.notify(user_id, "templateUpdated", {"template_id": template_id})


async def notify_exercise_updated(user_id: str, exercise_id: str) -> None:
    await sync_notifier.notify(user_id, "exerciseUpdated", {"exercise_id": exercise_id})


async def notify_schedule_updated(user_id: str) -> None:
    await sync_notifier.notify(user_id, "scheduleUpdated", {})
