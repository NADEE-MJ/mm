# Deployment

In production, a single FastAPI server process serves both the API and the compiled React frontend. There is no separate static hosting needed.

---

## How It Works

The FastAPI backend serves:

| Path | Serves |
|---|---|
| `/api/*` | API handlers |
| `/assets/*` | Frontend static assets (JS, CSS, images) |
| `/*` (catch-all) | `frontend/dist/index.html` (SPA entry) |

This means you can deploy the entire app with one process and one server.

---

## Production Build (Local)

Build the frontend:

```bash
cd frontend
npm install
npm run build
# Output: frontend/dist/
```

Copy `dist/` so the backend can find it (or configure `STATIC_FILES_DIR` to point to it):

```bash
cp -r frontend/dist backend/dist
```

Start the backend:

```bash
cd backend
uv sync
uv run uvicorn main:app --host 0.0.0.0 --port 8000
```

Access at `http://localhost:8000`.

---

## Deploying to Railway, Render, or Fly.io

These platforms run a single build and start command with a persistent volume for the SQLite database.

### Build Command

```bash
cd frontend && npm install && npm run build && cd ../backend && uv sync
```

### Start Command

```bash
cd backend && uv run uvicorn main:app --host 0.0.0.0 --port $PORT
```

### Persistent Volume

Attach a persistent disk and mount it at a path the backend uses for the SQLite file. Set `DATABASE_URL` to point to that path:

```env
DATABASE_URL=sqlite:////data/app.db
```

### Environment Variables

Set these in the platform's environment configuration:

| Variable | Value |
|---|---|
| `TMDB_API_KEY` | Your TMDB API key |
| `OMDB_API_KEY` | Your OMDb API key |
| `SECRET_KEY` | Long random string for JWT signing |
| `CORS_ORIGINS` | Comma-separated list of allowed origins (or `*`) |
| `DATABASE_URL` | `sqlite:////data/app.db` (or your volume path) |

---

## Running Migrations in Production

Run Alembic before starting the server:

```bash
cd backend && uv run alembic upgrade head
```

On platforms that support release commands (Railway, Render), set this as the release command so it runs before each deploy.

The backend also runs `ensure_additive_schema()` on startup, which manually adds any new columns that Alembic may not have caught (SQLite compatibility fallback). This is a safety net, not a replacement for migrations.

---

## Updating the iOS App

The iOS app's backend URL is baked into the IPA at build time. When you change your production backend URL:

1. Update the `MOBILE_API_BASE_URL` repository secret
2. Trigger a new build (push to `main` or use manual dispatch)
3. Download and reinstall the new IPA

---

## Security Checklist

- [ ] `SECRET_KEY` is a long random string unique to production (do not use the dev default)
- [ ] `CORS_ORIGINS` is set to your actual domain, not `*`
- [ ] TMDB and OMDb keys are server-side only (never in frontend code)
- [ ] Database volume is not publicly accessible
- [ ] HTTPS is enforced at the load balancer or hosting platform level
- [ ] Backend API accessible only over HTTPS (required for iOS ATS)

---

## Related Docs

- [Local Development](local-development.md)
- [Environment Variables](../reference/environment-variables.md)
- [iOS Build & Distribution](ios-build.md)
