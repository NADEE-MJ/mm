# MM — Movie Manager

FastAPI + React/Vite + SwiftUI + SQLite (via SQLAlchemy/Alembic) + TMDB/OMDb APIs

## Structure

- `backend/` — FastAPI REST API
  - `app/api/routers/` — endpoints: auth, backup, external (TMDB/OMDb), health, lists, movies, people, ranking, sync
  - `app/schemas/` — Pydantic models for lists, movies, people, ranking, sync
  - `app/services/` — business logic (backup, conflict_resolver, external_apis, movies, notifications, ranking, security)
  - `alembic/versions/` — DB migrations (3: initial, rankings, liked_field)
- `frontend/` — React + Vite + TypeScript + Tailwind
  - `src/pages/` — Account, Admin, Lists, Movies, People, PersonDetail
  - `src/components/` — AddMovie, AuthScreen, MovieCard, MovieDetail, MovieDetailPanel, MoviePosterCard, PeopleManager, RatingPrompt, UserStats
  - `src/contexts/` — AuthContext, MoviesContext, RankingContext
  - `src/hooks/` — usePeople, useRankingSession, useSync
  - `src/services/` — api.ts, omdbAPI.ts, tmdbAPI.ts
- `mobile/` — SwiftUI iOS app (XcodeGen via `project.yml`)
  - `Sources/Models/`, `Services/`, `Views/`, `Theme/`
- `docs/` — architecture, features, reference, setup docs

## Commands (via `npm run` or `bash scripts/mm-cli.sh`)

- `npm run install:all` — install backend + frontend deps
- `npm run build:frontend` — build frontend
- `npm run frontend:dev` — Vite dev server
- `npm run backend:start` — run FastAPI
- `npm run backend:migrate` — run Alembic migrations
- `npm run swift:xcodegen` — regenerate Xcode project
- `npm run swift:build` / `swift:run` — build/run iOS app
- `npm run start` — production start

## Key Patterns

- External API integration (TMDB for movie data, OMDb as fallback)
- Ranking system with head-to-head comparison (RankingContext, useRankingSession)
- People management with movie associations
- Sync service for offline→server data sync
- iOS app follows same service pattern as gymbo (shared architecture)
