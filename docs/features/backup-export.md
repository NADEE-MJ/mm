# Backup and Export

Movie Manager supports:
- manual export/import
- optional daily server-side backups (14-day retention)

## Export Format (v2)

`GET /api/backup/export` returns condensed user data.

```json
{
  "version": 2,
  "exported_at": 1739550000.0,
  "movies": [
    {
      "imdb_id": "tt1234567",
      "status": "toWatch",
      "custom_list_id": null,
      "last_modified": 1739550000.0,
      "recommendations": [
        {
          "person_name": "Alice",
          "date_recommended": 1739550000.0,
          "vote_type": true
        }
      ],
      "watch_history": {
        "date_watched": 1739550000.0,
        "my_rating": 8.5
      }
    }
  ],
  "people": [],
  "lists": []
}
```

Not included:
- `user_id`
- internal foreign keys like `person_id`
- API-fetchable metadata blobs (`tmdb_data`, `omdb_data`)

## Import

`POST /api/backup/import` accepts the same v2 payload.

Current response shape:

```json
{
  "success": true,
  "imported_counts": {
    "movies": 142,
    "people": 8,
    "lists": 3
  },
  "imdb_ids_needing_enrichment": ["tt1234567"],
  "errors": []
}
```

When `imdb_ids_needing_enrichment` is non-empty, clients can call `POST /api/movies/{imdb_id}/refresh` to fetch TMDB/OMDb metadata.

## Settings and Server Backups

- `GET /api/backup/settings`
- `PUT /api/backup/settings`
- `GET /api/backup/list`
- `POST /api/backup/restore/{filename}`

Scheduler behavior:
- Runs daily at 3:00 AM (server time)
- Backs up users with `backup_enabled = true`
- Stores `backups/{user_id}/YYYY-MM-DD.json`
- Removes files older than 14 days

## Client UX

### Web (`frontend/src/pages/AccountPage.tsx`)

- Auto-backup toggle
- Export Library download
- Import Library from JSON file

### iOS (`mobile/Sources/Views/Tabs/AccountPageView.swift`)

- Auto-backup toggle
- Export via share sheet
- Import via file picker

## Related Docs

- [API Reference](../reference/api.md)
- [Database Schema](../reference/database-schema.md)
- [Mobile Architecture](../architecture/mobile.md)
- [Frontend Architecture](../architecture/frontend.md)
