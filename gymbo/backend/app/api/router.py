"""Central place to wire routers onto the FastAPI app."""

from fastapi import FastAPI

from app.api.routers import (
    auth,
    backup,
    exercises,
    health,
    metrics,
    schedule,
    sessions,
    sync,
    templates,
    workout_types,
)


def register_routers(app: FastAPI) -> None:
    http_routers = (
        auth.router,
        backup.router,
        exercises.router,
        health.router,
        metrics.router,
        schedule.router,
        sessions.router,
        sync.router,
        templates.router,
        workout_types.router,
    )
    for router in http_routers:
        app.include_router(router, prefix="/api")

    app.include_router(sync.ws_router)


__all__ = ["register_routers"]
