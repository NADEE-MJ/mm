# Movie Manager Documentation

Movie Manager is a full-stack movie recommendation tracker with a React web client, a native Swift iOS app, and a FastAPI backend.

```text
Clients (Web + iOS)
        |
 REST + WebSocket
        |
FastAPI + SQLite + Alembic
        |
 TMDB / OMDb proxy + cache
```

| Platform | Stack |
|---|---|
| Backend | FastAPI, SQLAlchemy, SQLite, Alembic |
| Web | React, Vite, Tailwind CSS |
| iOS | SwiftUI, GRDB, XcodeGen |

## Architecture
- [Backend](architecture/backend.md) - API, auth, models, sync, backups
- [Frontend](architecture/frontend.md) - React app structure and data flow
- [Mobile](architecture/mobile.md) - SwiftUI app architecture, offline cache, sync

## Features
- [Movies](features/movies.md) - Add, rate, status, watch history
- [People & Recommenders](features/people.md) - Recommenders, trust, quick keys
- [Backup & Export](features/backup-export.md) - Export/import format and scheduled backups

## Setup
- [Local Development](setup/local-development.md) - Backend, frontend, and iOS local setup
- [iOS Build & Distribution](setup/ios-build.md) - GitHub Actions IPA build and release flow
- [Deployment](setup/deployment.md) - Production hosting

## Reference
- [API Reference](reference/api.md) - Backend endpoints
- [Database Schema](reference/database-schema.md) - Backend and iOS local schema
- [Environment Variables](reference/environment-variables.md) - Config for local/dev/CI
