"""FastAPI application factory and top-level routes."""

from __future__ import annotations

import logging
import sys
from pathlib import Path

from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from app.api.router import register_routers
from app.config import config
from app.services.backup import backup_manager
from app.services.seed import seed_user_data
from database import SessionLocal, engine
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from models import Base, User

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


async def _scheduled_backup_job() -> None:
    db = SessionLocal()
    try:
        users = db.query(User).filter(User.backup_enabled.is_(True)).all()
        for user in users:
            await backup_manager.backup_user_data(db, user.id)
            await backup_manager.cleanup_old_backups(user.id)
        db.commit()
    finally:
        db.close()


def create_app() -> FastAPI:
    app = FastAPI(title="Gymbo API", version="0.1.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_routers(app)

    if STATIC_PATH.exists():
        app.mount("/assets", StaticFiles(directory=STATIC_PATH / "assets"), name="assets")

        @app.get("/{full_path:path}")
        async def serve_spa(full_path: str) -> FileResponse:  # noqa: ARG001
            index_path = STATIC_PATH / "index.html"
            return FileResponse(index_path)

    @app.on_event("startup")
    async def startup_event() -> None:
        alembic_cfg = Config(BACKEND_DIR / "alembic.ini")
        with engine.connect() as conn:
            migration_ctx = MigrationContext.configure(conn)
            current_rev = migration_ctx.get_current_revision()

        script = __import__("alembic.script", fromlist=["ScriptDirectory"]).ScriptDirectory
        script_dir = script.from_config(alembic_cfg)
        head_rev = script_dir.get_current_head()

        if current_rev != head_rev:
            logger.error(
                "Database migration mismatch: current=%s, head=%s. "
                "Run `alembic upgrade head` before starting the server.",
                current_rev,
                head_rev,
            )
            sys.exit(1)

        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        try:
            users = db.query(User).all()
            for user in users:
                seed_user_data(db, user.id)
        finally:
            db.close()

        if scheduler and not scheduler.running:
            scheduler.add_job(_scheduled_backup_job, "interval", hours=24)
            scheduler.start()

    @app.on_event("shutdown")
    async def shutdown_event() -> None:
        if scheduler and scheduler.running:
            scheduler.shutdown(wait=False)

    return app


app = create_app()
