# Backup / Import / Export System Plan

## Context
The backend already has a `BackupManager` with `GET /backup/export` and `POST /backup/import` endpoints, plus a daily scheduled backup at 3 AM with 30-day retention. However:
- The export includes full `tmdb_data` / `omdb_data` (API-fetchable, shouldn't be in portable export files)
- No user preference to enable/disable auto-backups
- Scheduled backup is daily (user wants up to hourly) with 30-day retention (user wants 2 weeks)
- Neither the mobile app nor the frontend surface any backup/export/import UI

---

## Condensed Export Format (version 2)
Manual exports and server-side scheduled backups strip API-fetchable data. Only user-specific data is stored:
```json
{
  "version": 2,
  "exported_at": 1234567890.0,
  "movies": [
    {
      "imdb_id": "tt1234567",
      "status": "toWatch",
      "custom_list_id": null,
      "last_modified": 1234567890.0,
      "recommendations": [
        { "person_name": "Alice", "date_recommended": 1234567890.0, "vote_type": true }
      ],
      "watch_history": { "date_watched": 1234567890.0, "my_rating": 8.5 }
    }
  ],
  "people": [
    { "name": "Alice", "is_trusted": true, "color": "#ff0000", "emoji": "🎬", "last_modified": 1234567890.0 }
  ],
  "lists": [
    { "id": "uuid", "name": "Favorites", "color": "#ff0000", "icon": "star", "position": 0, "created_at": 1234567890.0, "last_modified": 1234567890.0 }
  ]
}
```
Omits: `user_id`, `person_id` (internal), `tmdb_data`, `omdb_data`.

On import, movies are created as stubs. The import response includes `imdb_ids_needing_enrichment` — the client then calls the existing `/movies/{imdb_id}/refresh` endpoint in the background for each.

---

## Changes

### 1. Backend — `backend/app/services/backup.py`
- Add `build_condensed_payload(db, user_id)` — new method returning v2 format (no tmdb_data/omdb_data, no user_id/person_id in recs)
- Keep `build_backup_payload()` unchanged (used internally; full data for server-side disaster recovery if ever needed, though scheduled backups will also use condensed)
- Update `backup_user_data()` to call `build_condensed_payload()` instead
- Keep file naming as `YYYY-MM-DD.json` — daily files, no change needed
- `cleanup_old_backups()` already parses this format correctly
- Change `RETENTION_DAYS = 14` (was 30)
- Update `restore_from_backup()` to handle v2 condensed format:
  - Use `person_name` from rec directly (no `person_id` lookup needed)
  - After all movies inserted, collect `imdb_ids_needing_enrichment` (movies with no tmdb_data) and return them in the response
- Rename `run_daily_backups()` → `run_scheduled_backups()`, skip users where `backup_enabled == False`

### 2. Backend — `backend/app/api/routers/backup.py`
- Update `GET /backup/export` to call `build_condensed_payload()` (condensed v2)
- Add `GET /backup/list` — returns list of available backup file names/timestamps for current user:
  ```json
  { "backups": [{ "filename": "2026-02-12_14.json", "created_at": 1234567890.0, "size_bytes": 4096 }] }
  ```
- Add `POST /backup/restore/{filename}` — restores from a specific server-side backup file for current user
- Add `PUT /backup/settings` — toggle auto-backup:
  ```json
  // request body
  { "backup_enabled": true }
  // response
  { "backup_enabled": true }
  ```

### 3. Backend — `backend/models.py`
- Add `backup_enabled: bool` column to `User` model, default `False`

### 4. Backend — `backend/app/main.py`
- Keep scheduler as `cron(hour=3, minute=0)` (daily at 3AM) — no change needed
- Update job call from `run_daily_backups` → `run_scheduled_backups`
- Add `backup_enabled` to `ensure_additive_schema()` for SQLite compatibility:
  ```sql
  ALTER TABLE users ADD COLUMN backup_enabled BOOLEAN DEFAULT 0
  ```

### 5. Backend — `backend/alembic/versions/` (new migration)
- Add migration to add `backup_enabled BOOLEAN DEFAULT FALSE` to users table

### 6. Frontend — `frontend/src/services/api.ts`
- Add `exportBackup(): Promise<Blob>` — calls `GET /backup/export`, returns Blob for download
- Add `importBackup(data: object): Promise<ImportResult>` — `POST /backup/import`
- Add `getBackupSettings(): Promise<{backup_enabled: bool}>` — GET user's backup preference
- Add `updateBackupSettings(enabled: bool)` — `PUT /backup/settings`
- Add `listBackups()` — `GET /backup/list`

### 7. Frontend — `frontend/src/pages/AccountPage.tsx`
Add a "Data & Backup" card section with:
- **Auto-backup toggle** — fetches current setting on mount, calls `updateBackupSettings()` on change, shows subtitle "Saves your library daily on the server (14 days retained)"
- **Export Library button** — calls `exportBackup()`, triggers browser download of `moviemanager-export-{date}.json`
- **Import Library button** — `<input type="file" accept=".json">` hidden, button triggers it; on file selected calls `importBackup()`, shows result toast (counts + enrichment notice if any)

### 8. Mobile Swift — `mobile/Sources/Services/NetworkService.swift`
Add functions to `NetworkService`:
- `exportBackup() async throws -> Data` — `GET /backup/export`
- `importBackup(_ payload: [String: Any]) async throws -> ImportResult` — `POST /backup/import`
- `getBackupSettings() async throws -> BackupSettings` — `GET /backup/settings` (or via user profile)
- `updateBackupSettings(enabled: Bool) async throws` — `PUT /backup/settings`
- `listBackups() async throws -> [BackupFileInfo]` — `GET /backup/list`

### 9. Mobile Swift — `mobile/Sources/Views/Tabs/AccountPageView.swift`
Add a "Data & Backup" section inside `SettingsView` (or a new `BackupView` navigated from SettingsView):
- **Auto-backup toggle** — `@State var backupEnabled: Bool`, loaded on appear, calls `updateBackupSettings()` on change
- **Export Library button** — calls `exportBackup()`, wraps data in a temp file, presents `ShareLink` / `UIActivityViewController`
- **Import Library button** — uses `.fileImporter(allowedContentTypes: [.json])` modifier; on success, reads file and calls `importBackup()`; shows result alert with counts and "refreshing movie data" if enrichment needed
- After successful import: calls `repository.syncNow()` to reload, then queues refresh for any stubs

---

## Critical Files
| File                                                    | Change                                                                  |
| ------------------------------------------------------- | ----------------------------------------------------------------------- |
| `backend/app/services/backup.py`                        | Condensed format, hourly naming, 14-day retention, backup_enabled check |
| `backend/app/api/routers/backup.py`                     | New /list, /restore/{filename}, /settings endpoints                     |
| `backend/models.py`                                     | Add backup_enabled to User                                              |
| `backend/app/main.py`                                   | Hourly scheduler, ensure_additive_schema for backup_enabled             |
| `backend/alembic/versions/<new>.py`                     | Migration for backup_enabled column                                     |
| `frontend/src/services/api.ts`                          | New backup API functions                                                |
| `frontend/src/pages/AccountPage.tsx`                    | Data & Backup section                                                   |
| `mobile/Sources/Services/NetworkService.swift`    | New backup network calls                                                |
| `mobile/Sources/Views/Tabs/AccountPageView.swift` | Data & Backup UI in SettingsView                                        |

---

## Verification
1. **Backend**: Start server, call `GET /api/backup/export` — response should be v2 condensed JSON (no tmdb_data). Call `PUT /api/backup/settings` with `{"backup_enabled": true}`, confirm User record updated. Trigger `run_scheduled_backups` manually, confirm `backups/{user_id}/YYYY-MM-DD_HH.json` created. Call `GET /api/backup/list`, confirm file appears. Call `POST /api/backup/restore/{filename}`, confirm data restored.
2. **Frontend**: Toggle auto-backup switch, verify toggle persists on reload. Click Export, confirm file download with condensed JSON. Click Import, select the exported file, confirm toast shows correct counts.
3. **Mobile**: In SettingsView > Data & Backup, toggle auto-backup, verify stored. Tap Export Library, confirm share sheet appears with JSON file. Tap Import Library, pick JSON, confirm alert shows import counts and sync re-runs.
