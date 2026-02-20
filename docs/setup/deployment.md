# Deployment

In production, one FastAPI process serves both API routes and the built React app.

## Static Serving Model

Backend (`backend/app/main.py`) serves:

| Path | Purpose |
|---|---|
| `/api/*` | API endpoints |
| `/assets/*` | Frontend build assets |
| `/*` | `frontend/dist/index.html` (SPA entry) |

The backend expects the frontend build at `frontend/dist` (repo-root relative).

## Build Steps

### 1. Build frontend

```bash
cd frontend
npm install
npm run build
```

### 2. Install backend deps + run migrations

```bash
cd ../backend
uv sync
uv run alembic upgrade head
```

### 3. Start backend

```bash
uv run uvicorn main:app --host 0.0.0.0 --port $PORT
```

## Environment Variables

Set at deploy time:

- `TMDB_API_KEY`
- `OMDB_API_KEY`
- `ADMIN_TOKEN`
- `SECRET_KEY` (required in production)
- `DATABASE_URL` (point to persistent storage)
- `CORS_ORIGINS`

Example DB URL with mounted volume:

```env
DATABASE_URL=sqlite:////data/app.db
```

## Hosting Notes

For Railway/Render/Fly-style platforms, use:

Build command:

```bash
cd frontend && npm install && npm run build && cd ../backend && uv sync
```

Start command:

```bash
cd backend && uv run uvicorn main:app --host 0.0.0.0 --port $PORT
```

## iOS Build Dependency

The iOS workflow bakes backend URL into IPA via `MOBILE_API_BASE_URL`.
When backend URL changes:
1. Update `MOBILE_API_BASE_URL` secret.
2. Trigger a new iOS build.
3. Reinstall the new IPA.

## Related Docs

- [Local Development](local-development.md)
- [Environment Variables](../reference/environment-variables.md)
- [iOS Build & Distribution](ios-build.md)
