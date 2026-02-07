"""Central place to wire routers onto the FastAPI app."""

from fastapi import FastAPI

from app.api.routers import auth, backup, external, health, lists, movies, people, sync


def register_routers(app: FastAPI) -> None:
    """Attach all API and websocket routers."""
    http_routers = (
        auth.router,
        backup.router,
        external.router,
        health.router,
        lists.router,
        movies.router,
        people.router,
        sync.router,
    )
    for router in http_routers:
        app.include_router(router, prefix="/api")

    app.include_router(sync.ws_router)


__all__ = ["register_routers"]
