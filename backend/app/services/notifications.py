"""Broadcast helpers for sync notifications."""

from __future__ import annotations

import time
from typing import Dict, Set

from fastapi import WebSocket


class SyncNotifier:
    """Tracks WebSocket connections and pushes change notifications."""

    def __init__(self) -> None:
        self.connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.connections.setdefault(user_id, set()).add(websocket)
        await websocket.send_json({"type": "connected", "timestamp": time.time()})

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        if user_id not in self.connections:
            return
        self.connections[user_id].discard(websocket)
        if not self.connections[user_id]:
            self.connections.pop(user_id, None)

    async def broadcast(self, user_id: str, message: dict) -> None:
        for connection in list(self.connections.get(user_id, set())):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(user_id, connection)


sync_notifier = SyncNotifier()


async def notify_movie_change(user_id: str, imdb_id: str) -> None:
    """Emit an event telling clients a movie was updated."""
    await sync_notifier.broadcast(
        user_id,
        {
            "type": "movieUpdated",
            "imdb_id": imdb_id,
            "timestamp": time.time(),
        },
    )


async def notify_people_change(user_id: str) -> None:
    """Emit an event letting clients refresh people lists."""
    await sync_notifier.broadcast(
        user_id,
        {
            "type": "peopleUpdated",
            "timestamp": time.time(),
        },
    )
