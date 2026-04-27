# Mobile (iOS Swift) Architecture

The iOS app is a native SwiftUI client in `mobile/`. It uses GRDB (SQLite) for local caching and queued offline operations, and syncs with the FastAPI backend.

## File Structure

```text
mobile/
├── project.yml
├── Config/
│   ├── App.xcconfig
│   └── Env.generated.xcconfig
├── scripts/
│   └── generate-env-xcconfig.sh
├── Sources/
│   ├── MovieManagerApp.swift
│   ├── Models/
│   │   └── TabItem.swift
│   ├── Services/
│   │   ├── AppConfiguration.swift
│   │   ├── AppLogging.swift
│   │   ├── AuthManager.swift
│   │   ├── BiometricAuthManager.swift
│   │   ├── DatabaseManager.swift
│   │   ├── MovieRepository.swift
│   │   ├── NetworkService.swift
│   │   ├── Repository.swift
│   │   ├── SyncManager.swift
│   │   └── WebSocketManager.swift
│   ├── Views/
│   │   ├── RootTabHostView.swift
│   │   ├── AddMoviePageView.swift
│   │   ├── AddPersonFullScreenView.swift
│   │   ├── LoginView.swift
│   │   ├── Tabs/
│   │   │   ├── HomePageView.swift
│   │   │   ├── PeoplePageView.swift
│   │   │   └── AccountPageView.swift
│   │   └── Components/
│   │       └── CachedAsyncImage.swift
│   ├── Theme/
│   │   └── AppTheme.swift
│   └── Info.plist
└── MovieManager.xcodeproj
```

## Runtime Architecture

- `NetworkService` handles HTTP APIs and backup endpoints.
- `DatabaseManager` manages GRDB schema and local cache.
- `MovieRepository` provides local-first reads and write orchestration.
- `SyncManager` replays queued operations and enriches pending movies.
- `WebSocketManager` listens for server change events.

## Tabs

`RootTabHostView` defines:
- Movies
- People
- Discover
- Account

## Local Storage

GRDB tables include:
- `movies`
- `people`
- `pending_operations`
- `pending_movies`

This supports offline reads and deferred write replay.

## API Configuration

Build-time API URL flow:
1. `mobile/.env` contains `API_BASE_URL` (or `MOBILE_API_BASE_URL`).
2. Optional file log flag comes from `FILE_LOGGING_ENABLED` (or `MOBILE_FILE_LOGGING_ENABLED`) and must be `YES`/`NO` (defaults to `NO`).
3. `scripts/generate-env-xcconfig.sh` writes `Config/Env.generated.xcconfig`.
4. `Sources/Info.plist` reads `$(API_BASE_URL)` and `$(FILE_LOGGING_ENABLED)`.
5. `NetworkService` reads URL from app config.

CI sets `MOBILE_API_BASE_URL` secret and optionally `MOBILE_FILE_LOGGING_ENABLED` (variable/secret), then generates the same xcconfig in workflow.

## Build and Run

```bash
cd mobile
./scripts/generate-env-xcconfig.sh
xcodegen generate
open MovieManager.xcodeproj
```

## CI/CD

Workflow: `.github/workflows/build-mobile.yml`

- Builds unsigned IPA artifact `mobile-unsigned-ipa`
- Publishes versioned release tag `mobile-v{MARKETING_VERSION}` on eligible main/manual runs

## Related Docs

- [iOS Build & Distribution](../setup/ios-build.md)
- [Environment Variables](../reference/environment-variables.md)
- [Database Schema](../reference/database-schema.md)
