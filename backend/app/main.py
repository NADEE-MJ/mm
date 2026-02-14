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
    """Apply SQLite compatibility migrations for older local databases."""
    with engine.begin() as conn:
        if conn.dialect.name != "sqlite":
            return

        def columns_for(table_name: str) -> set[str]:
            rows = conn.exec_driver_sql(f"PRAGMA table_info({table_name})").mappings().all()
            return {row["name"] for row in rows}

        def table_exists(table_name: str) -> bool:
            return (
                conn.exec_driver_sql(
                    "SELECT 1 FROM sqlite_master WHERE type='table' AND name=:name LIMIT 1",
                    {"name": table_name},
                ).scalar()
                is not None
            )

        people_exists = table_exists("people")
        recommendations_exists = table_exists("recommendations")

        people_columns = columns_for("people") if people_exists else set()
        recommendation_columns = (
            columns_for("recommendations") if recommendations_exists else set()
        )

        # Migrate legacy schema:
        # - people composite PK (name,user_id) -> integer person id
        # - recommendations.person(string)+vote_type(string) -> person_id+vote_type(bool)
        needs_people_rebuild = people_exists and "id" not in people_columns
        needs_recommendation_rebuild = recommendations_exists and (
            "person_id" not in recommendation_columns or "person" in recommendation_columns
        )

        if people_exists and recommendations_exists and (
            needs_people_rebuild or needs_recommendation_rebuild
        ):
            conn.exec_driver_sql("DROP TABLE IF EXISTS recommendations_new")
            conn.exec_driver_sql("DROP TABLE IF EXISTS people_new")

            conn.exec_driver_sql(
                """
                CREATE TABLE people_new (
                    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                    name VARCHAR NOT NULL,
                    user_id VARCHAR NOT NULL,
                    is_trusted BOOLEAN,
                    color VARCHAR,
                    emoji VARCHAR,
                    last_modified FLOAT,
                    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
                )
                """
            )

            trusted_expr = "is_trusted" if "is_trusted" in people_columns else "0"
            color_expr = (
                "COALESCE(color, '#0a84ff')" if "color" in people_columns else "'#0a84ff'"
            )
            emoji_expr = "emoji" if "emoji" in people_columns else "NULL"
            last_modified_expr = (
                "last_modified"
                if "last_modified" in people_columns
                else "strftime('%s','now')"
            )
            conn.exec_driver_sql(
                f"""
                INSERT INTO people_new (name, user_id, is_trusted, color, emoji, last_modified)
                SELECT name, user_id, {trusted_expr}, {color_expr}, {emoji_expr}, {last_modified_expr}
                FROM people
                """
            )

            if "person" in recommendation_columns:
                conn.exec_driver_sql(
                    """
                    INSERT INTO people_new (name, user_id, is_trusted, color, emoji, last_modified)
                    SELECT DISTINCT r.person, r.user_id, 0, '#0a84ff', NULL, strftime('%s','now')
                    FROM recommendations r
                    LEFT JOIN people_new p
                      ON p.user_id = r.user_id AND p.name = r.person
                    WHERE p.id IS NULL AND r.person IS NOT NULL
                    """
                )

            conn.exec_driver_sql(
                "CREATE UNIQUE INDEX uq_person_name_per_user_new ON people_new(user_id, name)"
            )

            conn.exec_driver_sql(
                """
                CREATE TABLE recommendations_new (
                    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                    imdb_id VARCHAR NOT NULL,
                    user_id VARCHAR NOT NULL,
                    person_id INTEGER NOT NULL,
                    date_recommended FLOAT,
                    vote_type BOOLEAN NOT NULL DEFAULT 1,
                    FOREIGN KEY(imdb_id, user_id) REFERENCES movies (imdb_id, user_id) ON DELETE CASCADE,
                    FOREIGN KEY(person_id) REFERENCES people_new (id) ON DELETE CASCADE
                )
                """
            )

            if "person" in recommendation_columns:
                vote_expr = (
                    "CASE WHEN lower(COALESCE(r.vote_type, 'upvote')) IN ('upvote', '1', 'true', 't', 'yes') THEN 1 ELSE 0 END"
                    if "vote_type" in recommendation_columns
                    else "1"
                )
                date_expr = (
                    "COALESCE(r.date_recommended, strftime('%s','now'))"
                    if "date_recommended" in recommendation_columns
                    else "strftime('%s','now')"
                )
                conn.exec_driver_sql(
                    f"""
                    WITH ranked AS (
                        SELECT
                            r.id,
                            r.imdb_id,
                            r.user_id,
                            p.id AS person_id,
                            {date_expr} AS date_recommended,
                            {vote_expr} AS vote_type_bool,
                            ROW_NUMBER() OVER (
                                PARTITION BY r.imdb_id, r.user_id, p.id
                                ORDER BY COALESCE(r.date_recommended, 0) DESC, r.id DESC
                            ) AS rn
                        FROM recommendations r
                        JOIN people_new p
                          ON p.user_id = r.user_id AND p.name = r.person
                    )
                    INSERT INTO recommendations_new (id, imdb_id, user_id, person_id, date_recommended, vote_type)
                    SELECT id, imdb_id, user_id, person_id, date_recommended, vote_type_bool
                    FROM ranked
                    WHERE rn = 1
                    """
                )
            else:
                conn.exec_driver_sql(
                    """
                    WITH ranked AS (
                        SELECT
                            r.id,
                            r.imdb_id,
                            r.user_id,
                            r.person_id,
                            COALESCE(r.date_recommended, strftime('%s','now')) AS date_recommended,
                            CASE
                                WHEN CAST(r.vote_type AS TEXT) IN ('1', 'true', 'True', 'upvote', 'UPVOTE') THEN 1
                                ELSE 0
                            END AS vote_type_bool,
                            ROW_NUMBER() OVER (
                                PARTITION BY r.imdb_id, r.user_id, r.person_id
                                ORDER BY COALESCE(r.date_recommended, 0) DESC, r.id DESC
                            ) AS rn
                        FROM recommendations r
                    )
                    INSERT INTO recommendations_new (id, imdb_id, user_id, person_id, date_recommended, vote_type)
                    SELECT id, imdb_id, user_id, person_id, date_recommended, vote_type_bool
                    FROM ranked
                    WHERE rn = 1
                    """
                )

            conn.exec_driver_sql("DROP TABLE recommendations")
            conn.exec_driver_sql("DROP TABLE people")
            conn.exec_driver_sql("ALTER TABLE people_new RENAME TO people")
            conn.exec_driver_sql("ALTER TABLE recommendations_new RENAME TO recommendations")

            conn.exec_driver_sql("DROP INDEX IF EXISTS uq_person_name_per_user_new")
            conn.exec_driver_sql(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_person_name_per_user ON people(user_id, name)"
            )
            conn.exec_driver_sql(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_recommendation_per_person ON recommendations(imdb_id, user_id, person_id)"
            )
            conn.exec_driver_sql(
                "CREATE INDEX IF NOT EXISTS ix_recommendations_user_person ON recommendations(user_id, person_id)"
            )
            conn.exec_driver_sql(
                "CREATE INDEX IF NOT EXISTS ix_recommendations_movie_user ON recommendations(imdb_id, user_id)"
            )

            # Re-read columns after migration.
            people_columns = columns_for("people")
            recommendation_columns = columns_for("recommendations")

        if people_exists:
            if "color" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN color VARCHAR")
                conn.exec_driver_sql("UPDATE people SET color = '#0a84ff' WHERE color IS NULL")
            if "emoji" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN emoji VARCHAR")
            if "quick_key" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN quick_key VARCHAR")
            if "last_modified" not in people_columns:
                conn.exec_driver_sql("ALTER TABLE people ADD COLUMN last_modified FLOAT")
                conn.exec_driver_sql(
                    "UPDATE people SET last_modified = strftime('%s','now') WHERE last_modified IS NULL"
                )
            conn.exec_driver_sql(
                "CREATE INDEX IF NOT EXISTS ix_people_user_last_modified ON people(user_id, last_modified)"
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
            conn.exec_driver_sql(
                "CREATE INDEX IF NOT EXISTS ix_custom_lists_user_last_modified ON custom_lists(user_id, last_modified)"
            )

        if recommendations_exists:
            recommendation_columns = columns_for("recommendations")
            if "vote_type" not in recommendation_columns:
                conn.exec_driver_sql(
                    "ALTER TABLE recommendations ADD COLUMN vote_type BOOLEAN DEFAULT 1"
                )
                conn.exec_driver_sql(
                    "UPDATE recommendations SET vote_type = 1 WHERE vote_type IS NULL"
                )

        if table_exists("movies"):
            movie_columns = columns_for("movies")
            if "media_type" not in movie_columns:
                conn.exec_driver_sql(
                    "ALTER TABLE movies ADD COLUMN media_type VARCHAR DEFAULT 'movie'"
                )
                conn.exec_driver_sql(
                    "UPDATE movies SET media_type = 'movie' WHERE media_type IS NULL"
                )
            conn.exec_driver_sql(
                "CREATE INDEX IF NOT EXISTS ix_movies_user_last_modified ON movies(user_id, last_modified)"
            )
        if table_exists("movie_status"):
            conn.exec_driver_sql(
                "CREATE INDEX IF NOT EXISTS ix_movie_status_user_custom_list ON movie_status(user_id, custom_list_id)"
            )
        if table_exists("users"):
            user_columns = columns_for("users")
            if "backup_enabled" not in user_columns:
                conn.exec_driver_sql(
                    "ALTER TABLE users ADD COLUMN backup_enabled BOOLEAN DEFAULT 0"
                )
                conn.exec_driver_sql(
                    "UPDATE users SET backup_enabled = 0 WHERE backup_enabled IS NULL"
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
                await backup_manager.run_scheduled_backups(db)
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
    if full_path:
        static_file = (STATIC_PATH / full_path).resolve()
        # Prevent path traversal: ensure resolved path stays inside STATIC_PATH
        if static_file.is_relative_to(STATIC_PATH.resolve()) and static_file.is_file():
            return FileResponse(str(static_file))

    index_file = STATIC_PATH / "index.html"
    if index_file.exists():
        return FileResponse(str(index_file))

    raise HTTPException(
        status_code=500,
        detail="Frontend not built. Run 'cd frontend && npm run build' first.",
    )


__all__ = ["app", "create_app"]
