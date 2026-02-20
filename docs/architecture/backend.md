# Backend Architecture

The backend is a **FastAPI** application backed by **SQLite** via **SQLAlchemy**. It serves the REST API, proxies external movie data from TMDB and OMDb, handles authentication, and runs scheduled backup jobs.

---

## File Structure

```
backend/
├── main.py                  # FastAPI app entry point, scheduler
├── models.py                # SQLAlchemy ORM models
├── database.py              # Database engine and session factory
├── auth.py                  # JWT authentication, user creation, quick recommender seeding
├── pyproject.toml           # Python dependencies (managed with uv)
├── alembic.ini              # Alembic migration config
├── alembic/
│   └── versions/            # Migration files
├── app/
│   ├── api/
│   │   └── routers/
│   │       ├── movies.py    # Movie CRUD endpoints
│   │       ├── people.py    # People/recommender endpoints
│   │       ├── backup.py    # Backup/export/import endpoints
│   │       └── sync.py      # Sync protocol endpoints
│   ├── schemas/
│   │   ├── movies.py        # Pydantic request/response models
│   │   └── people.py
│   └── services/
│       └── backup.py        # Backup business logic
└── app.db                   # SQLite database (gitignored)
```

---

## Framework & Dependencies

| Package | Purpose |
|---|---|
| `fastapi` | Web framework with automatic OpenAPI docs |
| `uvicorn` | ASGI server |
| `sqlalchemy` | ORM and query builder |
| `alembic` | Database migrations |
| `pydantic` | Request/response validation |
| `python-jose` | JWT token handling |
| `hashlib` (stdlib) | Password hashing (PBKDF2-SHA256) |
| `httpx` | Async HTTP client for TMDB/OMDb |
| `apscheduler` | Scheduled backup jobs |

Dependencies are managed with **uv**. The lockfile is committed; install with `uv sync`.

---

## Database Models

### User
```
users
├── id              UUID (PK)
├── email           TEXT UNIQUE NOT NULL
├── username        TEXT UNIQUE NOT NULL
├── hashed_password TEXT NOT NULL        ← PBKDF2-SHA256, stored as "salt$hash"
├── created_at      FLOAT
├── is_active       BOOLEAN DEFAULT true
└── backup_enabled  BOOLEAN DEFAULT false
```

### Movie
```
movies
├── imdb_id         TEXT (PK)        ← IMDb ID e.g. "tt1234567"
├── user_id         UUID (FK users)
├── tmdb_data       TEXT (JSON blob)  ← Full TMDB response
├── omdb_data       TEXT (JSON blob)  ← Full OMDb response
└── last_modified   FLOAT            ← Unix timestamp
```

### Person (Recommender)
```
people
├── id              INTEGER (PK)
├── user_id         UUID (FK users)
├── name            TEXT
├── is_trusted      BOOLEAN
├── color           TEXT             ← Hex color e.g. "#ff0000"
├── emoji           TEXT
└── quick_key       TEXT NULLABLE    ← "youtube"|"oscar"|"random_person"|"google"
```

### Recommendation
```
recommendations
├── id               INTEGER (PK, AUTOINCREMENT)
├── imdb_id          TEXT (FK movies composite key)
├── user_id          TEXT (FK movies composite key)
├── person_id        INTEGER (FK people.id)
├── date_recommended FLOAT
└── vote_type        BOOLEAN NOT NULL DEFAULT true  ← true=upvote, false=downvote
```
Unique constraint: `(imdb_id, user_id, person_id)`. `person_name` is a computed ORM property, not a stored column.

### WatchHistory
```
watch_history
├── imdb_id      TEXT (PK, FK movies)
├── user_id      UUID (FK users)
├── date_watched FLOAT
└── my_rating    FLOAT               ← 1.0–10.0
```

### MovieStatus
```
movie_status
├── imdb_id  TEXT (PK, FK movies)
├── user_id  UUID (FK users)
└── status   TEXT  ← "toWatch"|"watched"|"deleted"|"custom"
```

### CustomList
```
custom_lists
├── id            UUID (PK)
├── user_id       UUID (FK users)
├── name          TEXT
├── color         TEXT
├── icon          TEXT
├── position      INTEGER
├── created_at    FLOAT
└── last_modified FLOAT
```

---

## Authentication

JWT-based authentication. Passwords are hashed with **PBKDF2-SHA256** (100,000 iterations), stored as `salt$hash`.

- `POST /api/auth/admin/login` — Exchange the server `ADMIN_TOKEN` for a short-lived admin JWT
- `POST /api/auth/admin/users` — Admin-only: create a user account; seeds 4 quick recommenders
- `POST /api/auth/login` — Login with `{"email", "password"}` JSON body; returns `access_token` + `user` object; tokens expire after 30 days
- `GET /api/auth/me` — Verify token; returns current user

User creation is **admin-only** — there is no public self-registration endpoint. Token verification distinguishes network errors (offline) from auth errors (invalid token). The mobile iOS app uses this to avoid logging users out when they're simply offline.

**Quick recommender seeding** happens inside `create_user()` in `auth.py`. After the user row is committed, `seed_quick_recommenders(db, user_id)` inserts the four canonical quick-recommender Person rows with their stable `quick_key` values.

---

## External API Proxy

The backend proxies all TMDB and OMDb calls. Clients never need API keys.

**TMDB endpoints used:**
- Movie search: `GET /search/movie`
- Movie details: `GET /movie/{tmdb_id}`
- Movie credits: `GET /movie/{tmdb_id}/credits`

**OMDb endpoints used:**
- Movie ratings by IMDb ID: `GET /?i={imdb_id}`

**Caching:** Responses are cached in-memory with a 1-hour TTL, max 500 entries. This dramatically reduces external API calls for frequently-viewed movies.

**Movie enrichment:** When a movie is imported without full metadata (e.g., from a backup import), the `GET /api/movies/{imdb_id}/refresh` endpoint re-fetches and stores TMDB + OMDb data.

---

## Sync Protocol

The sync system allows clients to send write operations as discrete actions. This supports offline-first clients that queue operations locally.

- `GET /api/sync?since={timestamp}` — Returns all records modified after the given Unix timestamp
- `POST /api/sync` — Processes a single queued action

**Action types** (sent in `POST /api/sync` body):
| Action | Effect |
|---|---|
| `addMovie` | Create movie + recommendation |
| `updateMovieStatus` | Change status |
| `watchMovie` | Record watch + rating |
| `addPerson` | Create person |
| `updatePerson` | Change name/color/emoji/trust |
| `deletePerson` | Remove person (blocked for quick recommenders) |

---

## Backup & Scheduled Jobs

The scheduler runs inside `main.py` using **APScheduler**, configured for a daily job at 3 AM.

- `run_scheduled_backups()` — Iterates users where `backup_enabled = true` and writes a condensed JSON export to the server filesystem under `backups/{user_id}/YYYY-MM-DD.json`
- Retention: 14 days (older files purged automatically)

See [Backup & Export](../features/backup-export.md) for the full export format and API endpoints.

---

## SQLite Compatibility (ensure_additive_schema)

Because SQLite has limited `ALTER TABLE` support, `main.py` includes an `ensure_additive_schema()` function that runs on startup. It manually executes `ALTER TABLE ... ADD COLUMN` for any new columns that don't yet exist (falling back gracefully if they already do). This prevents startup failures during rolling deploys.

New columns added this way:
```sql
ALTER TABLE users ADD COLUMN backup_enabled BOOLEAN DEFAULT 0;
```

---

## Running Locally

```bash
cd backend
uv sync
cp .env.example .env
# edit .env: add TMDB_API_KEY, OMDB_API_KEY
uv run alembic upgrade head
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at `http://localhost:8000/docs`.

---

## Related Docs

- [API Reference](../reference/api.md)
- [Database Schema](../reference/database-schema.md)
- [Environment Variables](../reference/environment-variables.md)
- [Backup & Export](../features/backup-export.md)
