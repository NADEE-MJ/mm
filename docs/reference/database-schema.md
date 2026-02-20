# Database Schema

---

## Backend — SQLite (SQLAlchemy + Alembic)

The backend uses SQLite with SQLAlchemy ORM. Migrations are managed by Alembic.

### users

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID (TEXT) | PRIMARY KEY | |
| `email` | TEXT | UNIQUE, NOT NULL, indexed | Login identifier |
| `username` | TEXT | UNIQUE, NOT NULL, indexed | Display name |
| `hashed_password` | TEXT | NOT NULL | PBKDF2-SHA256 (`salt$hash`) |
| `created_at` | FLOAT | | Unix timestamp |
| `is_active` | BOOLEAN | DEFAULT true | Account enabled flag |
| `backup_enabled` | BOOLEAN | DEFAULT false | Auto-backup opt-in |

### movies

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `imdb_id` | TEXT | PRIMARY KEY | e.g. `tt1234567` |
| `user_id` | UUID | FK users.id, NOT NULL | |
| `tmdb_data` | TEXT | | JSON blob from TMDB API |
| `omdb_data` | TEXT | | JSON blob from OMDb API |
| `last_modified` | FLOAT | | Unix timestamp |
| `media_type` | TEXT | | `"movie"` or `"tv"` |
| `custom_list_id` | UUID | FK custom_lists.id, NULLABLE | |

### people

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | |
| `user_id` | UUID | FK users.id, NOT NULL | |
| `name` | TEXT | NOT NULL | Display name |
| `is_trusted` | BOOLEAN | DEFAULT false | |
| `color` | TEXT | | Hex color |
| `emoji` | TEXT | | |
| `quick_key` | TEXT | NULLABLE | `"youtube"`, `"oscar"`, `"random_person"`, `"google"` |
| `last_modified` | FLOAT | | Unix timestamp |

Unique constraint: `(user_id, name)`

`quick_key` is set at row creation and never updated.

### recommendations

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | |
| `imdb_id` | TEXT | FK movies.(imdb_id, user_id), NOT NULL | |
| `user_id` | TEXT | FK movies.(imdb_id, user_id), NOT NULL | |
| `person_id` | INTEGER | FK people.id, NOT NULL | |
| `date_recommended` | FLOAT | | Unix timestamp |
| `vote_type` | BOOLEAN | NOT NULL, DEFAULT true | true = upvote, false = downvote |

Unique constraint: `(imdb_id, user_id, person_id)` — one vote per person per movie.

`person_name` is a computed `@property` on the ORM model (`person_ref.name`), not a stored column.

### watch_history

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `imdb_id` | TEXT | PRIMARY KEY, FK movies.imdb_id | One record per movie |
| `user_id` | UUID | FK users.id, NOT NULL | |
| `date_watched` | FLOAT | | Unix timestamp |
| `my_rating` | FLOAT | | 1.0–10.0 |

### movie_status

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `imdb_id` | TEXT | PRIMARY KEY, FK movies.(imdb_id, user_id) | |
| `user_id` | TEXT | PRIMARY KEY, FK movies.(imdb_id, user_id) | |
| `status` | TEXT | NOT NULL, DEFAULT 'toWatch' | `toWatch`, `watched`, `deleted`, `custom` |
| `custom_list_id` | TEXT | NULLABLE | Set when status is `custom` |

Check constraint: `status IN ('toWatch', 'watched', 'deleted', 'custom')`

### custom_lists

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID (TEXT) | PRIMARY KEY | |
| `user_id` | UUID | FK users.id, NOT NULL | |
| `name` | TEXT | NOT NULL | |
| `color` | TEXT | | Hex color |
| `icon` | TEXT | | SF Symbol name or emoji |
| `position` | INTEGER | DEFAULT 0 | Sort order |
| `created_at` | FLOAT | | Unix timestamp |
| `last_modified` | FLOAT | | Unix timestamp |

---

## Mobile — SQLite (GRDB)

The iOS app maintains its own local SQLite database for offline-first access.

### movies (GRDB)

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | GRDB internal rowid |
| `tmdb_id` | INTEGER | |
| `imdb_id` | TEXT | |
| `title` | TEXT | |
| `poster_path` | TEXT | NULLABLE |
| `status` | TEXT | |
| `my_rating` | INTEGER | NULLABLE |
| `date_watched` | TEXT | NULLABLE |
| `cached_at` | REAL | When this record was cached |
| `json_data` | TEXT | Full Movie JSON for reconstruction |

### people (GRDB)

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | GRDB internal rowid |
| `name` | TEXT | |
| `is_trusted` | BOOLEAN | |
| `movie_count` | INTEGER | |
| `color` | TEXT | NULLABLE |
| `emoji` | TEXT | NULLABLE |
| `quick_key` | TEXT | NULLABLE |

### pending_operations (GRDB)

Offline write queue. Operations are replayed in order when connectivity returns.

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT | UUID (PK) |
| `type` | TEXT | e.g. `"add_movie"`, `"update_movie"`, `"watch_movie"` |
| `payload` | TEXT | JSON payload for the operation |
| `created_at` | REAL | Unix timestamp |
| `retry_count` | INTEGER | DEFAULT 0; max 3 before dropping |

### pending_movies (GRDB)

Movies added offline (by title only) that need TMDB enrichment when online.

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT | UUID (PK) |
| `title` | TEXT | User-provided title |
| `recommender` | TEXT | Recommender name |
| `created_at` | REAL | Unix timestamp |
| `needs_enrichment` | BOOLEAN | Always true for offline additions |

---

## Backup Export Schema (v2)

The portable export format (see [Backup & Export](../features/backup-export.md)):

```
root
├── version          INTEGER  = 2
├── exported_at      FLOAT    Unix timestamp
├── movies[]
│   ├── imdb_id          TEXT
│   ├── status           TEXT
│   ├── custom_list_id   TEXT | null
│   ├── last_modified    FLOAT
│   ├── recommendations[]
│   │   ├── person_name       TEXT
│   │   ├── date_recommended  FLOAT
│   │   └── vote_type         BOOLEAN | null
│   └── watch_history    object | null
│       ├── date_watched  FLOAT
│       └── my_rating     FLOAT
├── people[]
│   ├── name           TEXT
│   ├── is_trusted     BOOLEAN
│   ├── color          TEXT
│   ├── emoji          TEXT
│   └── last_modified  FLOAT
└── lists[]
    ├── id             TEXT (UUID)
    ├── name           TEXT
    ├── color          TEXT
    ├── icon           TEXT
    ├── position       INTEGER
    ├── created_at     FLOAT
    └── last_modified  FLOAT
```

**Not included in exports**: `user_id`, `person_id`, `tmdb_data`, `omdb_data`

---

## Related Docs

- [Backend Architecture](../architecture/backend.md)
- [Mobile Architecture](../architecture/mobile.md)
- [Backup & Export](../features/backup-export.md)
- [API Reference](api.md)
