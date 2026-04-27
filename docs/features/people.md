# People & Recommenders

People are the recommenders in your library — anyone who has suggested a movie to you. The app tracks who recommended each movie and lets you mark people as trusted or untrusted, which affects how their recommendations are surfaced.

---

## Person Fields

| Field | Type | Description |
|---|---|---|
| `name` | TEXT | Display name (user-editable) |
| `is_trusted` | BOOLEAN | Trust status for filtering |
| `color` | TEXT | Hex color for avatar display |
| `emoji` | TEXT | Emoji for avatar display |
| `quick_key` | TEXT (nullable) | Stable identity key for quick recommenders |

---

## Quick Recommenders

Quick recommenders represent common non-person sources of recommendations (a YouTube video, an awards show, a Google result, a random encounter). They are created automatically when a new user account is registered and have special protections.

### The Four Quick Recommenders

| Key | Default Name | Color | Emoji |
|---|---|---|---|
| `youtube` | Random YouTube Video | `#bf5af2` | 📺 |
| `oscar` | Oscar Winner/Nominee | `#ffd60a` | 🏆 |
| `random_person` | Random Person | `#30d158` | 🤝 |
| `google` | Google Search | `#64d2ff` | 🔎 |

### Stable Identity via `quick_key`

Each quick recommender has a `quick_key` column in the database. This key is immutable — it never changes, even if the user renames the person.

Previously, quick recommenders were identified by matching on their name (e.g., checking if a person is named "Random YouTube Video"). This broke if users renamed them. The `quick_key` column solves this: identity is tied to the key, not the display name.

### Seeding on Account Creation

`seed_quick_recommenders(db, user_id)` runs inside `create_user()` in `backend/auth.py` immediately after the user row is committed. It inserts all four quick recommenders as `Person` rows for the new user.

### Delete Protection

Quick recommenders cannot be deleted via `DELETE /api/people/{name}`. The people router checks `if db_person.quick_key is not None` and returns HTTP 400 before deleting.

### Renaming

Users can rename quick recommenders freely. The `quick_key` is not included in `PersonUpdate` schema, so it cannot be changed via the API — only the display name, color, and emoji can be updated.

---

## Trust Status

The `is_trusted` flag lets you mark recommenders you trust. The People page and movie filtering can be scoped to trusted-only or untrusted-only people.

When you rate a movie **below 6**, the app prompts you to review other recommendations from that person. This is where untrusting someone typically happens.

---

## People Page — Web

The web frontend People page shows all recommenders with:
- Recommendation count
- Trusted/untrusted status toggle
- Filter: All / Trusted / Untrusted
- Filter: Quick recommenders (identified by `quick_key !== null`)
- Sort: by name, recommendation count, etc.

Quick recommenders display a purple **"Quick"** badge/pill.

## People Page — iOS

The iOS `PeoplePageView` shows all recommenders with:
- Filter tabs: All / Trusted / Quick
- Quick recommenders display a purple bolt icon (`bolt.fill`)
- Recommendation count badge per person

---

## Add Movie — Recommender Picker

In the Add Movie flow (web and iOS), recommenders are shown in two sections:

**Section 1: Quick**
- The four quick recommenders
- Shown first, always
- Purple badge/bolt icon

**Section 2: People**
- Regular user-added recommenders
- Sorted by most recently used or alphabetically

Multiple recommenders can be selected for a single movie.

---

## Sync

People sync to the backend via the sync protocol. The `quick_key` field is included in:
- `GET /api/people` response (`PersonResponse` schema)
- `POST /api/sync` `addPerson` action payload
- The mobile `CachedPerson` SQLite record

The `quick_key` is **not** writable via `updatePerson` sync actions — it is set at creation and never changes.

---

## Related Docs

- [Movies](movies.md)
- [API Reference](../reference/api.md)
- [Database Schema](../reference/database-schema.md)
