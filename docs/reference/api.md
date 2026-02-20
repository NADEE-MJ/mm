# API Reference

All endpoints are prefixed with `/api`. The backend is a **FastAPI** application — interactive docs are available at `http://localhost:8000/docs` when running locally.

Authentication uses **JWT Bearer tokens**. Include the token in the `Authorization` header:

```
Authorization: Bearer <token>
```

---

## Auth

User creation is **admin-only** — accounts are provisioned by an administrator, not self-registered.

### Create User (Admin Only)

Requires an admin JWT obtained from `POST /api/auth/admin/login`.

```
POST /api/auth/admin/users
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "email": "alice@example.com",
  "username": "alice",
  "password": "secret123"
}
```

Response: `201 Created`
```json
{
  "id": "uuid",
  "email": "alice@example.com",
  "username": "alice",
  "created_at": 1234567890.0,
  "is_active": true
}
```

Automatically seeds 4 quick recommenders for the new user.

### Admin Login

Exchanges the server-side `ADMIN_TOKEN` for a short-lived admin JWT (12 hours).

```
POST /api/auth/admin/login
Content-Type: application/json

{ "token": "<ADMIN_TOKEN value>" }
```

Response:
```json
{ "access_token": "eyJ...", "token_type": "bearer" }
```

### Login

```
POST /api/auth/login
Content-Type: application/json

{
  "email": "alice@example.com",
  "password": "secret123"
}
```

Response:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": {
    "id": "uuid",
    "email": "alice@example.com",
    "username": "alice",
    "created_at": 1234567890.0,
    "is_active": true
  }
}
```

Tokens expire after **30 days**.

### Verify Token / Get Current User

```
GET /api/auth/me
Authorization: Bearer <token>
```

Response:
```json
{
  "id": "uuid",
  "email": "alice@example.com",
  "username": "alice",
  "created_at": 1234567890.0,
  "is_active": true
}
```

Returns `401` if the token is invalid or expired.

---

## Movies

### List Movies

```
GET /api/movies
Authorization: Bearer <token>
```

Response: array of movie objects with status, recommendations, and watch history.

### Get Movie

```
GET /api/movies/{imdb_id}
Authorization: Bearer <token>
```

### Add Movie

```
POST /api/movies
Authorization: Bearer <token>
Content-Type: application/json

{
  "imdb_id": "tt1234567",
  "tmdb_id": 12345,
  "recommender": "Alice"
}
```

Fetches TMDB and OMDb data and stores the movie. Creates a recommendation record.

### Update Movie Status

```
PUT /api/movies/{imdb_id}/status
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "watched"
}
```

Valid statuses: `toWatch`, `watched`, `deleted`, `custom`

### Mark Watched

```
PUT /api/movies/{imdb_id}/watch
Authorization: Bearer <token>
Content-Type: application/json

{
  "date_watched": 1234567890.0,
  "my_rating": 8.5
}
```

### Refresh Movie Metadata

```
GET /api/movies/{imdb_id}/refresh
Authorization: Bearer <token>
```

Re-fetches TMDB and OMDb data and updates the stored record. Used after import to enrich stub movies.

---

## Recommendations

### Add Recommendation

```
POST /api/movies/{imdb_id}/recommendations
Authorization: Bearer <token>
Content-Type: application/json

{
  "person_name": "Alice",
  "date_recommended": 1234567890.0,
  "vote_type": true
}
```

### Remove Recommendation

```
DELETE /api/movies/{imdb_id}/recommendations/{person_name}
Authorization: Bearer <token>
```

---

## People

### List People

```
GET /api/people
Authorization: Bearer <token>
```

Response:
```json
[
  {
    "id": 1,
    "name": "Alice",
    "is_trusted": true,
    "color": "#ff0000",
    "emoji": "🎬",
    "quick_key": null,
    "movie_count": 5
  },
  {
    "id": 2,
    "name": "Random YouTube Video",
    "is_trusted": false,
    "color": "#bf5af2",
    "emoji": "📺",
    "quick_key": "youtube",
    "movie_count": 12
  }
]
```

### Add Person

```
POST /api/people
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Bob",
  "color": "#00ff00",
  "emoji": "🎥"
}
```

### Update Person

```
PUT /api/people/{name}
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Robert",
  "is_trusted": true,
  "color": "#0000ff",
  "emoji": "🍿"
}
```

`quick_key` is not writable via this endpoint.

### Delete Person

```
DELETE /api/people/{name}
Authorization: Bearer <token>
```

Returns `400` if the person has a `quick_key` (quick recommenders cannot be deleted).

### Get Person Stats

```
GET /api/people/{name}/stats
Authorization: Bearer <token>
```

Returns recommendation counts, movie list, and trust status.

---

## Sync

### Get Changes Since Timestamp

```
GET /api/sync?since={unix_timestamp}
Authorization: Bearer <token>
```

Returns all movies and people records modified after the given timestamp. Used by offline clients to pull updates.

### Process Queued Action

```
POST /api/sync
Authorization: Bearer <token>
Content-Type: application/json

{
  "action": "updateMovieStatus",
  "data": {
    "imdb_id": "tt1234567",
    "status": "watched"
  },
  "timestamp": 1234567890.0
}
```

**Action types:**

| Action | Required `data` fields |
|---|---|
| `addMovie` | `imdb_id`, `tmdb_id`, `recommender` |
| `updateMovieStatus` | `imdb_id`, `status` |
| `watchMovie` | `imdb_id`, `date_watched`, `my_rating` |
| `addPerson` | `name`, `color`, `emoji`, `is_trusted` |
| `updatePerson` | `name`, and any of `color`, `emoji`, `is_trusted` |
| `deletePerson` | `name` |

---

## Backup

### Export

```
GET /api/backup/export
Authorization: Bearer <token>
```

Returns the user's library as a v2 condensed JSON payload. See [Backup & Export](../features/backup-export.md) for the format spec.

### Import

```
POST /api/backup/import
Authorization: Bearer <token>
Content-Type: application/json

{ ...v2 payload... }
```

Response:
```json
{
  "movies_imported": 142,
  "people_imported": 8,
  "lists_imported": 3,
  "imdb_ids_needing_enrichment": ["tt1234567"]
}
```

### Get Backup Settings

```
GET /api/backup/settings
Authorization: Bearer <token>
```

Response:
```json
{ "backup_enabled": false }
```

### Update Backup Settings

```
PUT /api/backup/settings
Authorization: Bearer <token>
Content-Type: application/json

{ "backup_enabled": true }
```

### List Server Backups

```
GET /api/backup/list
Authorization: Bearer <token>
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
Authorization: Bearer <token>
```

Same response format as import.

---

## Health

```
GET /api/health
```

Response:
```json
{ "status": "ok" }
```

No authentication required.

---

## Custom Lists

### List Custom Lists

```
GET /api/lists
Authorization: Bearer <token>
```

### Create Custom List

```
POST /api/lists
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Favorites",
  "color": "#ff0000",
  "icon": "star"
}
```

### Update Custom List

```
PUT /api/lists/{list_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Top Picks",
  "color": "#00ff00",
  "position": 1
}
```

### Delete Custom List

```
DELETE /api/lists/{list_id}
Authorization: Bearer <token>
```

---

## Related Docs

- [Backend Architecture](../architecture/backend.md)
- [Database Schema](database-schema.md)
- [Backup & Export](../features/backup-export.md)
