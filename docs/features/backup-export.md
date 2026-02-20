# Backup & Export

Movie Manager supports exporting your library to a portable JSON file and importing it back. Server-side scheduled backups are also available per user, with 14-day retention.

---

## Export Format (Version 2)

The condensed v2 export strips API-fetchable data (TMDB metadata, OMDb ratings) and keeps only user-specific data. This makes exports small and portable — metadata is re-fetched from TMDB on import.

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
        {
          "person_name": "Alice",
          "date_recommended": 1234567890.0,
          "vote_type": true
        }
      ],
      "watch_history": {
        "date_watched": 1234567890.0,
        "my_rating": 8.5
      }
    }
  ],
  "people": [
    {
      "name": "Alice",
      "is_trusted": true,
      "color": "#ff0000",
      "emoji": "🎬",
      "last_modified": 1234567890.0
    }
  ],
  "lists": [
    {
      "id": "uuid",
      "name": "Favorites",
      "color": "#ff0000",
      "icon": "star",
      "position": 0,
      "created_at": 1234567890.0,
      "last_modified": 1234567890.0
    }
  ]
}
```

**Omitted fields**: `user_id`, `person_id` (internal), `tmdb_data`, `omdb_data`

**`watch_history`** is `null` for unwatched movies.

---

## Import & Enrichment

`POST /api/backup/import` accepts a v2 JSON file and:

1. Upserts all people, lists, and movies from the file
2. Creates movie rows as **stubs** (no TMDB/OMDb data yet)
3. Returns:
   ```json
   {
     "movies_imported": 142,
     "people_imported": 8,
     "lists_imported": 3,
     "imdb_ids_needing_enrichment": ["tt1234567", "tt7654321"]
   }
   ```
4. The client calls `GET /api/movies/{imdb_id}/refresh` for each ID in `imdb_ids_needing_enrichment` in the background to populate TMDB/OMDb data

This keeps import fast (no external API calls during the import request itself) while still resulting in fully-enriched records.

---

## API Endpoints

### Export

```
GET /api/backup/export
```

Returns a v2 condensed JSON payload for the authenticated user. Suitable for browser download or share sheet.

### Import

```
POST /api/backup/import
Content-Type: application/json

{ ...v2 payload... }
```

### Settings

```
PUT /api/backup/settings
Content-Type: application/json

{ "backup_enabled": true }
```

Response:
```json
{ "backup_enabled": true }
```

Toggles whether the scheduled backup job includes this user.

### List Server Backups

```
GET /api/backup/list
```

Response:
```json
{
  "backups": [
    {
      "filename": "2026-02-12.json",
      "created_at": 1234567890.0,
      "size_bytes": 4096
    }
  ]
}
```

### Restore from Server Backup

```
POST /api/backup/restore/{filename}
```

Restores the user's data from a specific server-side backup file. Same semantics as import: stubs created, enrichment IDs returned.

---

## Scheduled Server Backups

The backend scheduler runs daily at **3 AM** and writes backup files for all users where `backup_enabled = true`.

- **Location**: `backups/{user_id}/YYYY-MM-DD.json`
- **Format**: v2 condensed (same as manual export)
- **Retention**: 14 days (files older than 14 days are purged automatically)

The scheduler is configured in `backend/app/main.py` using **APScheduler**.

---

## User Settings Column

The `users` table has a `backup_enabled BOOLEAN DEFAULT false` column. New users have auto-backup disabled by default. They opt in via `PUT /api/backup/settings`.

This column was added via Alembic migration and also via the `ensure_additive_schema()` startup function for SQLite compatibility.

---

## Web Frontend UI

On the Account page, a **Data & Backup** section contains:

| Control | Behavior |
|---|---|
| Auto-backup toggle | Fetches current setting on mount; calls `PUT /api/backup/settings` on change; subtitle: "Saves your library daily on the server (14 days retained)" |
| Export Library | Calls `GET /api/backup/export`, triggers browser download named `moviemanager-export-{YYYY-MM-DD}.json` |
| Import Library | Hidden `<input type="file" accept=".json">` triggered by button; on file select calls `POST /api/backup/import`; shows result toast with counts and enrichment notice |

## iOS App UI

In the Account tab, a **Data & Backup** section contains:

| Control | Behavior |
|---|---|
| Auto-backup toggle | `@State var backupEnabled`, loaded on appear, calls `updateBackupSettings()` on change |
| Export Library | Calls `exportBackup()` → wraps data in a temp file → presents `ShareLink` / `UIActivityViewController` |
| Import Library | `.fileImporter(allowedContentTypes: [.json])` modifier; on success reads file and calls `importBackup()`; shows result alert with counts; if enrichment needed shows "refreshing movie data" |

After a successful import, `repository.syncNow()` is called to reload the local database, then enrichment refreshes are queued for any stubs.

---

## Related Docs

- [Backend Architecture](../architecture/backend.md)
- [Frontend Architecture](../architecture/frontend.md)
- [Mobile Architecture](../architecture/mobile.md)
- [API Reference](../reference/api.md)
