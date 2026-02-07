"""FastAPI application factory and top-level routes."""

from __future__ import annotations

import logging
from pathlib import Path

from app.api.router import register_routers
from app.config import config
from app.services.backup import backup_manager
from database import engine
from database import SessionLocal
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from models import Base

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

APP_DIR = Path(__file__).resolve().parent
BACKEND_DIR = APP_DIR.parent
PROJECT_ROOT = BACKEND_DIR.parent
STATIC_PATH = PROJECT_ROOT / "frontend" / "dist"
try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
except Exception:  # noqa: BLE001
    AsyncIOScheduler = None

scheduler = AsyncIOScheduler() if AsyncIOScheduler else None


def ensure_additive_schema() -> None:
    """Apply additive SQLite schema fixes for older local databases."""
    with engine.begin() as conn:
        if conn.dialect.name != "sqlite":
            return

        def columns_for(table_name: str) -> set[str]:
            rows = conn.exec_driver_sql(f"PRAGMA table_info({table_name})").mappings().all()
            return {row["name"] for row in rows}

        if "people" in conn.exec_driver_sql(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='people'"
        ).scalars().all():
            people_columns = columns_for("people")
            if "color" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN color VARCHAR")
                conn.exec_driver_sql("UPDATE people SET color = '#0a84ff' WHERE color IS NULL")
            if "emoji" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN emoji VARCHAR")
            if "last_modified" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN last_modified FLOAT")
                conn.exec_driver_sql(
                    "UPDATE people SET last_modified = strftime('%s','now') WHERE last_modified IS NULL"
                )

        if "custom_lists" in conn.exec_driver_sql(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='custom_lists'"
        ).scalars().all():
            list_columns = columns_for("custom_lists")
            if "last_modified" not in list_columns:
                conn.exec_driver_sql("ALTER TABLE custom_lists ADD COLUMN last_modified FLOAT")
                conn.exec_driver_sql(
                    "UPDATE custom_lists SET last_modified = strftime('%s','now') WHERE last_modified IS NULL"
                )

        if "recommendations" in conn.exec_driver_sql(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='recommendations'"
        ).scalars().all():
            recommendation_columns = columns_for("recommendations")
            if "vote_type" not in recommendation_columns:
                conn.exec_driver_sql(
                    "ALTER TABLE recommendations ADD COLUMN vote_type VARCHAR DEFAULT 'upvote'"
                )
                conn.exec_driver_sql(
                    "UPDATE recommendations SET vote_type = 'upvote' WHERE vote_type IS NULL"
                )


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    Base.metadata.create_all(bind=engine)
    ensure_additive_schema()

    application = FastAPI(title="Movie Recommendations API", version="2.0.0")
    configure_cors(application)
    register_routers(application)
    configure_static_routes(application)
    register_lifecycle_handlers(application)
    return application


def configure_cors(app: FastAPI) -> None:
    """Apply CORS configuration from environment."""
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


def configure_static_routes(app: FastAPI) -> None:
    """Mount built frontend assets if they exist."""
    if STATIC_PATH.exists():
        assets_path = STATIC_PATH / "assets"
        if assets_path.exists():
            app.mount("/assets", StaticFiles(directory=str(assets_path)), name="assets")
        logger.info("Static files mounted from: %s", STATIC_PATH)
    else:
        logger.warning("Static directory not found. Looked for: %s", STATIC_PATH)


def register_lifecycle_handlers(app: FastAPI) -> None:
    """Register startup/shutdown hooks."""

    @app.on_event("startup")
    async def startup_event() -> None:
        if scheduler is None:
            logger.warning("APScheduler not installed; daily backups are disabled.")
            return
        if scheduler.running:
            return

        async def _run_backups() -> None:
            db = SessionLocal()
            try:
                await backup_manager.run_daily_backups(db)
            finally:
                db.close()

        scheduler.add_job(_run_backups, "cron", hour=3, minute=0, id="daily-backups", replace_existing=True)
        scheduler.start()

    @app.on_event("shutdown")
    async def shutdown_event() -> None:
        if scheduler and scheduler.running:
            scheduler.shutdown(wait=False)


app = create_app()


@app.get("/{full_path:path}")
async def serve_frontend(full_path: str) -> FileResponse:
    """Serve the built SPA for non-API routes."""
    if full_path.startswith(("api/", "docs", "redoc", "openapi.json")):
        raise HTTPException(status_code=404, detail="Endpoint not found")

    # Serve static files directly if they exist (e.g., favicon, images)
    static_file = STATIC_PATH / full_path
    if full_path and static_file.exists() and static_file.is_file():
        return FileResponse(str(static_file))

    index_file = STATIC_PATH / "index.html"
    if index_file.exists():
        return FileResponse(str(index_file))

    raise HTTPException(
        status_code=500,
        detail="Frontend not built. Run 'cd frontend && npm run build' first.",
    )


__all__ = ["app", "create_app"]
