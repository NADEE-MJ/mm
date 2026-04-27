# API Reference

All HTTP endpoints are under `/api`.

Local docs UI when running backend:
- `http://localhost:8155/docs`

Auth uses bearer JWT:

```text
Authorization: Bearer <token>
```

## Auth

| Method | Path | Notes |
|---|---|---|
| `POST` | `/api/auth/login` | User login |
| `POST` | `/api/auth/admin/login` | Exchange `ADMIN_TOKEN` for admin JWT |
| `POST` | `/api/auth/admin/users` | Admin-only user creation |
| `GET` | `/api/auth/me` | Current user profile |

## Movies

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/movies` | List movies |
| `GET` | `/api/movies/{imdb_id}` | Get one movie |
| `POST` | `/api/movies/{imdb_id}/recommendations` | Add/update one recommendation |
| `POST` | `/api/movies/{imdb_id}/recommendations/bulk` | Add multiple recommendations |
| `DELETE` | `/api/movies/{imdb_id}/recommendations/{person_name}` | Remove recommendation |
| `PUT` | `/api/movies/{imdb_id}/watch` | Mark watched + rating |
| `PUT` | `/api/movies/{imdb_id}/status` | Update status |
| `POST` | `/api/movies/{imdb_id}/refresh` | Re-fetch TMDB/OMDb metadata |

## People

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/people` | List people/recommenders |
| `POST` | `/api/people` | Create person |
| `PUT` | `/api/people/{name}` | Update person fields |
| `DELETE` | `/api/people/{name}` | Delete person (blocked for quick recommenders) |
| `GET` | `/api/people/{name}/stats` | Person summary + movie list |

## Custom Lists

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/lists` | List custom lists |
| `POST` | `/api/lists` | Create list |
| `GET` | `/api/lists/{list_id}` | Get list |
| `PUT` | `/api/lists/{list_id}` | Update list |
| `DELETE` | `/api/lists/{list_id}` | Delete list |
| `GET` | `/api/lists/{list_id}/movies` | List movies in a list |

## Sync

### Change feed

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/sync?since=...` | Legacy change feed |
| `GET` | `/api/sync/changes?since=...&limit=...&offset=...` | Paginated change feed |

### Action processing

| Method | Path | Notes |
|---|---|---|
| `POST` | `/api/sync` | Process one action |
| `POST` | `/api/sync/batch` | Process multiple actions |

Single-action request shape:

```json
{
  "action": "updateStatus",
  "data": { "imdb_id": "tt1234567", "status": "watched" },
  "timestamp": 1739550000.0
}
```

Response shape:

```json
{
  "success": true,
  "last_modified": 1739550000.0,
  "error": null,
  "conflict": false,
  "server_state": null
}
```

Supported action names include:
- `addRecommendation`
- `removeRecommendation`
- `updateRecommendationVote`
- `markWatched`
- `updateRating`
- `updateStatus`
- `addPerson`
- `updatePerson`
- `updatePersonTrust`
- `deletePerson`
- `addList`
- `updateList`
- `deleteList`

### WebSocket

| Protocol | Path | Notes |
|---|---|---|
| `ws`/`wss` | `/ws/sync?token=<jwt>` | Realtime change events |

## Backup

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/backup/export` | Download user export JSON |
| `POST` | `/api/backup/import` | Import export payload |
| `GET` | `/api/backup/settings` | Read backup setting |
| `PUT` | `/api/backup/settings` | Update backup setting |
| `GET` | `/api/backup/list` | List server backup files |
| `POST` | `/api/backup/restore/{filename}` | Restore specific server backup |

Import/restore response shape:

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

## External API Proxy

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/external/tmdb/search?q=...` | TMDB search |
| `GET` | `/api/external/tmdb/discover/genre` | TMDB discover by genre |
| `GET` | `/api/external/tmdb/discover/person` | TMDB discover by person |
| `GET` | `/api/external/tmdb/discover/list` | TMDB list-based discover |
| `GET` | `/api/external/tmdb/movie/{tmdb_id}` | TMDB movie details |
| `GET` | `/api/external/tmdb/tv/{tmdb_id}` | TMDB TV details |
| `GET` | `/api/external/omdb/movie/{imdb_id}` | OMDb details |
| `GET` | `/api/external/cache/info` | Cache stats |

## Health

| Method | Path | Auth |
|---|---|---|
| `GET` | `/api/health` | No |

Response:

```json
{
  "status": "healthy",
  "timestamp": 1739550000.0
}
```

## Related Docs

- [Database Schema](database-schema.md)
- [Environment Variables](environment-variables.md)
- [Backup & Export](../features/backup-export.md)
