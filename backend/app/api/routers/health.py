"""Health endpoint."""

import time

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check() -> dict[str, float | str]:
    """Basic liveness probe."""
    return {"status": "healthy", "timestamp": time.time()}
