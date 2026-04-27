# Movie Manager

Full-stack movie recommendation tracker with:
- Web client (React + Vite)
- Native iOS client (SwiftUI + GRDB)
- FastAPI backend (SQLite + Alembic)

Full docs: [docs/README.md](docs/README.md)

## Current Stack

| Layer | Tech |
|---|---|
| Backend | FastAPI, SQLAlchemy, Alembic, SQLite |
| Web | React, Vite, Tailwind CSS |
| iOS | SwiftUI, GRDB, Nuke, XcodeGen |
| External data | TMDB, OMDb |

## Repository Layout

```text
mm/
├── backend/                 # FastAPI API + data model + migrations
├── frontend/                # React web app
├── mobile/                  # Native Swift iOS app
├── docs/                    # Project documentation
├── scripts/mm-cli.sh        # Repo CLI wrapper used by npm scripts
└── package.json             # Root scripts
```

## Quick Start (Web + Backend)

### 1. Install dependencies

```bash
npm run install:all
```

### 2. Configure backend env

```bash
cp backend/.env.example backend/.env
```

Set required keys in `backend/.env`:
- `TMDB_API_KEY`
- `OMDB_API_KEY`
- `ADMIN_TOKEN`

### 3. Run migrations

```bash
npm run backend:migrate
```

### 4. Start backend

```bash
npm run backend:start
```

Default backend URL: `http://localhost:8155`

### 5. Start frontend (new terminal)

```bash
npm run frontend:dev
```

Default frontend URL: `http://localhost:5173`

Set `frontend/.env` if needed:

```env
VITE_API_URL=http://localhost:8155
```

## Native iOS App (Swift)

```bash
cd mobile
cp .env.example .env
# edit .env if needed
./scripts/generate-env-xcconfig.sh
xcodegen generate
open MovieManager.xcodeproj
```

Notes:
- CI requires HTTPS via `MOBILE_API_BASE_URL`.
- Optional file logging is controlled by `FILE_LOGGING_ENABLED` (`YES`/`NO`, defaults to `NO`).
- Local HTTP development may require ATS exceptions in `mobile/Sources/Info.plist`.

## CI/CD

iOS workflow: `.github/workflows/build-mobile.yml`

Outputs:
- Artifact: `mobile-unsigned-ipa`
- Release tag (on main/manual publish): `mobile-v{MARKETING_VERSION}`
- IPA filename format: `mm-vX_Y.ipa` (or `mm-vX_Y-<suffix>.ipa`)

## Useful Commands

```bash
npm run help
npm run backend:migrate
npm run backend:migrate:status
npm run backend:migrate:down -- -1
npm run import:convert -- --help
npm run swift:xcodegen
npm run swift:build
npm run swift:run
```

## License

MIT (see `LICENSE`)
