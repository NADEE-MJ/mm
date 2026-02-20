# Local Development Setup

This guide covers backend, web frontend, and native iOS app setup.

## Prerequisites

| Tool | Version |
|---|---|
| Python | 3.11+ |
| uv | latest |
| Node.js | 18+ |
| Xcode | 16+ |
| XcodeGen | latest |

Also required for movie metadata:
- TMDB API key
- OMDb API key

## Backend

```bash
cd backend
uv sync
cp .env.example .env
```

Set at least:

```env
TMDB_API_KEY=your_tmdb_api_key
OMDB_API_KEY=your_omdb_api_key
ADMIN_TOKEN=your_admin_bootstrap_token
DATABASE_URL=sqlite:///./app.db
CORS_ORIGINS=http://localhost:5173
```

Run migrations and start API:

```bash
uv run alembic upgrade head
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8155
```

- API: `http://localhost:8155`
- OpenAPI docs: `http://localhost:8155/docs`

## Web Frontend (React + Vite)

```bash
cd frontend
npm install
cp .env.example .env
```

Set:

```env
VITE_API_URL=http://localhost:8155
```

Run dev server:

```bash
npm run dev
```

- Web app: `http://localhost:5173`

## Native iOS App (Swift)

Create `mobile/.env` manually (there is no committed `.env.example`):

```bash
cd mobile
cat > .env <<'ENV'
API_BASE_URL=http://localhost:8155/api
ENV
```

Generate config and project:

```bash
./scripts/generate-env-xcconfig.sh
xcodegen generate
open MovieManager.xcodeproj
```

Notes:
- CI enforces HTTPS for `MOBILE_API_BASE_URL`.
- For local HTTP endpoints on a physical device, add ATS exceptions in `mobile/Sources/Info.plist`.

## Root CLI Shortcuts

From repo root:

```bash
npm run install:all
npm run backend:migrate
npm run backend:start
npm run frontend:dev
npm run swift:xcodegen
npm run swift:build
npm run swift:run
```

`npm run backend:start` defaults to port `8155`.

## CSV Import Converter

```bash
npm run import:convert -- \
  --movies-csv "for_importing/Movies.csv" \
  --tv-csv "for_importing/TV Shows.csv" \
  --output "for_importing/converted-import.json"
```

## Related Docs

- [Environment Variables](../reference/environment-variables.md)
- [iOS Build & Distribution](ios-build.md)
- [Deployment](deployment.md)
