# Movie Manager — Documentation

Movie Manager is a full-stack, offline-first movie recommendation tracker. Add movies from TMDB, record who recommended them, mark them watched, and rate them.

```
┌─────────────────────────────────────────────────────────┐
│                        Clients                          │
│   ┌──────────────┐        ┌──────────────────────────┐  │
│   │  Web (PWA)   │        │    iOS Swift App         │  │
│   │  React/Vite  │        │    SwiftUI / GRDB        │  │
│   │  IndexedDB   │        │    SQLite (offline)      │  │
│   └──────┬───────┘        └──────────┬───────────────┘  │
└──────────┼───────────────────────────┼──────────────────┘
           │ HTTP / REST + WebSocket   │
           ▼                           ▼
┌─────────────────────────────────────────────────────────┐
│            FastAPI · SQLite · Alembic                   │
│         Auth · Movies · People · Backup · Sync          │
└──────────────────────────┬──────────────────────────────┘
                           │ Proxied + cached
                           ▼
           ┌───────────────────────────────┐
           │  TMDB (movie data)            │
           │  OMDb (ratings)               │
           └───────────────────────────────┘
```

| Platform | Stack |
|---|---|
| Backend | FastAPI · SQLAlchemy · SQLite · Alembic |
| Web | React · Vite · Tailwind · IndexedDB (PWA) |
| iOS | Swift 6 · SwiftUI · GRDB · XcodeGen |

---

## Architecture
- [Backend](architecture/backend.md) — FastAPI, auth, database models, sync, backup scheduler
- [Frontend](architecture/frontend.md) — React PWA, IndexedDB, offline sync queue
- [Mobile](architecture/mobile.md) — SwiftUI, GRDB, repository pattern, image caching, XcodeGen

## Features
- [Movies](features/movies.md) — Add, status, rating, watch history
- [People & Recommenders](features/people.md) — Recommenders, trust, quick recommenders
- [Backup & Export](features/backup-export.md) — Export format, import, scheduled backups

## Setup
- [Local Development](setup/local-development.md) — Backend, frontend, and iOS local setup
- [iOS Build & Distribution](setup/ios-build.md) — CI/CD, unsigned IPAs, AltServer, sideloading
- [Deployment](setup/deployment.md) — Production build and hosting

## Reference
- [API Reference](reference/api.md) — All backend endpoints
- [Database Schema](reference/database-schema.md) — Backend and mobile SQLite schemas
- [Environment Variables](reference/environment-variables.md) — All configuration variables
