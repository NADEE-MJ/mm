"""Helpers for last-write-wins conflict detection."""

from __future__ import annotations

from typing import Any, Callable


class ConflictResolver:
    """Timestamp-based conflict resolver with clock-skew tolerance."""

    CLOCK_SKEW_GRACE_SECONDS = 1.0

    @staticmethod
    def has_conflict(server_last_modified: float | None, client_timestamp: float | None) -> bool:
        """Return True when client is older than server (with skew grace)."""
        if server_last_modified is None or client_timestamp is None:
            return False
        return client_timestamp < (server_last_modified - ConflictResolver.CLOCK_SKEW_GRACE_SECONDS)

    @staticmethod
    def check_conflict(
        entity: Any,
        client_timestamp: float | None,
        serializer: Callable[[Any], dict] | None = None,
    ) -> dict | None:
        """Return conflict payload when server state is newer."""
        if not entity:
            return None

        server_last_modified = getattr(entity, "last_modified", None)
        if not ConflictResolver.has_conflict(server_last_modified, client_timestamp):
            return None

        payload: dict[str, Any] = {
            "conflict": True,
            "server_last_modified": server_last_modified,
        }
        if serializer:
            payload["server_state"] = serializer(entity)
        return payload

