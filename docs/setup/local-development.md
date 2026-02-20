# Local Development Setup

This guide covers setting up all three components — backend, frontend, and iOS app — for local development.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Python | 3.11+ | System package manager or pyenv |
| uv | latest | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Node.js | 18+ | System package manager or nvm |
| Xcode | 16+ | Mac App Store |
| XcodeGen | latest | `brew install xcodegen` |
| TMDB API key | — | [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api) |
| OMDb API key | — | [omdbapi.com/apikey.aspx](http://www.omdbapi.com/apikey.aspx) |

---

## Backend

```bash
cd backend
uv sync
cp .env.example .env
```

Edit `backend/.env`:

```env
TMDB_API_KEY=your_tmdb_api_key
OMDB_API_KEY=your_omdb_api_key
DATABASE_URL=sqlite:///./app.db
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
SECRET_KEY=any_long_random_string
ADMIN_TOKEN=any_long_random_string
```

Run migrations and start:

```bash
uv run alembic upgrade head
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- API: `http://localhost:8000`
- Interactive docs: `http://localhost:8000/docs`

### Database Migrations (CLI shortcuts)

From the repo root:

```bash
npm run backend:migrate              # Apply all pending migrations
npm run backend:migrate:status       # Show migration status
npm run backend:migrate:down -- -1   # Roll back one migration
```

Or directly:

```bash
cd backend
uv run alembic upgrade head
uv run alembic downgrade -1
uv run alembic revision --autogenerate -m "description"
```

---

## Frontend (Web PWA)

```bash
cd frontend
npm install
cp .env.example .env
```

Edit `frontend/.env`:

```env
VITE_API_URL=http://localhost:8000
```

Start:

```bash
npm run dev
# App at http://localhost:5173
```

### Clearing Local Data

To reset the browser's local database (useful when testing sync or import):

Open DevTools → Application → IndexedDB → right-click `movieRecommendations` → Delete database.

---

## iOS Swift App

### One-Time Setup

```bash
brew install xcodegen
```

### Per-Clone / Per-Pull Setup

```bash
cd mobile
cp .env.example .env  # or create .env manually
```

Edit `mobile/.env`:

```env
API_BASE_URL=https://your-backend.example.com/api
```

> **Note**: iOS enforces HTTPS (App Transport Security). For local development against an HTTP backend, you must add an ATS exception for your local IP in `Sources/Info.plist`.

Generate the xcconfig and Xcode project:

```bash
./scripts/generate-env-xcconfig.sh
xcodegen generate
```

Open in Xcode:

```bash
open MobileSwift.xcodeproj
```

Build and run on a simulator or connected device.

### Regenerating After `project.yml` Changes

`MobileSwift.xcodeproj` is gitignored. Any time `project.yml` changes (new source files, new dependencies, build setting changes), re-run:

```bash
cd mobile
xcodegen generate
```

---

## Data Import (CSV)

To convert a Notion movie/TV export CSV into an import JSON:

```bash
npm run import:convert -- \
  --movies-csv "for_importing/Movies.csv" \
  --tv-csv "for_importing/TV Shows.csv" \
  --output "for_importing/converted-import.json"
```

Then import via the Account page in the web or iOS app, or directly via `POST /api/backup/import`.

---

## Running Everything Together

In separate terminals:

```bash
# Terminal 1 — Backend
cd backend && uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2 — Frontend
cd frontend && npm run dev
```

The iOS app connects to whichever URL is set in `mobile/.env`.

---

## Troubleshooting

### Backend won't start

- Check Python version: `python --version` (need 3.11+)
- Reinstall dependencies: `uv sync --reinstall`
- Check if port 8000 is already in use: `lsof -i :8000`

### Frontend won't start

- Check Node version: `node --version` (need 18+)
- Delete node_modules and reinstall: `rm -rf node_modules && npm install`
- Check if port 5173 is in use: `lsof -i :5173`

### Sync not working

- Confirm backend is running and accessible
- Check browser console for CORS or network errors
- Verify `VITE_API_URL` in `frontend/.env` matches the backend port

### Movies not loading

- Verify `TMDB_API_KEY` and `OMDB_API_KEY` are set in `backend/.env`
- Check backend logs for API errors: `uv run uvicorn main:app --reload` shows request logs

### iOS: Xcode project missing

- Run `xcodegen generate` from the `mobile/` directory

### iOS: API connection refused

- Confirm the backend is running and reachable from the device/simulator
- Check `mobile/.env` has the correct IP and port
- For HTTP (local): add ATS exception for the IP in `Sources/Info.plist`

---

## Related Docs

- [Environment Variables](../reference/environment-variables.md)
- [iOS Build & Distribution](ios-build.md)
- [Deployment](deployment.md)
