# mm/backend/ — FastAPI REST API

Python/FastAPI backend for movie management with external API integration.

## Structure

- `main.py` — FastAPI app entry point
- `app/main.py` — app factory
- `app/api/router.py` — aggregates all API routers
- `app/api/routers/` — auth, backup, external (TMDB/OMDb), health, lists, movies, people, ranking, sync
- `app/schemas/` — Pydantic models for lists, movies, people, ranking, sync
- `app/services/` — backup, conflict_resolver, external_apis, movies, notifications, ranking, security
- `database.py` — SQLAlchemy async engine
- `models.py` — SQLAlchemy ORM models
- `auth.py` — JWT auth
- `alembic/versions/` — DB migrations (3 versions)
