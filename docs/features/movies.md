# Movies

Movies are the core entity in Movie Manager. Each movie has a status, zero or more recommenders, and optionally a watch record with a rating.

---

## Adding a Movie

### Web / Frontend

1. Tap the **+** button in the bottom navigation bar
2. Search for a movie by title — results come from TMDB via the backend
3. Select a movie from the results
4. Choose one or more recommenders (people who suggested it)
   - Quick recommenders (YouTube, Oscar, Random Person, Google) appear first with a purple "Quick" badge
   - Regular people from your people list follow
5. Tap **Add Recommendation**

The movie is immediately saved to local IndexedDB and queued for sync. It appears in the **To Watch** list right away.

### iOS App

1. Tap the **Explore** tab (bottom nav)
2. Search for a movie — TMDB results appear
3. Tap a movie to open the add sheet
4. Select recommender(s) from the picker
   - Quick recommenders appear in a dedicated section at the top
5. Confirm to add

---

## Movie Status

Every movie in your library has exactly one status:

| Status | Meaning |
|---|---|
| `toWatch` | In your watch queue |
| `watched` | You've seen it; has a watch record and rating |
| `custom` | Assigned to a custom list |
| `deleted` | Removed from active lists (soft delete) |

Status changes are instant and sync in the background. A movie is set to `custom` when it is placed into one of your custom lists; `custom_list_id` on the `movie_status` row identifies which list.

---

## Watching & Rating

When you mark a movie as watched:

1. A **watch record** is created with the current date/time
2. You rate the movie on a scale of **1–10** (the slider rounds to 0.5 increments)
3. The status changes to `watched`

### Low-Rating Prompt

If you rate a movie **below 6**, the app prompts you to review other movies from the same recommender. This lets you quickly move their other recommendations to `deleted` or a custom list if you don't trust their taste.

---

## Watch History

Each movie can have one watch record. The record stores:
- `date_watched` — Unix timestamp
- `my_rating` — Float 1.0–10.0

Re-watching a movie overwrites the existing watch record (no multi-watch history yet).

---

## Movie Data

Movie metadata comes from two external APIs, both proxied through the backend:

### TMDB Data
- Title, original title
- Release year
- Runtime
- Genres
- Overview / synopsis
- Poster path (image URL)
- Director, cast (top-billed)
- TMDB ID

### OMDb Data
- IMDb ID (used as the primary key throughout the app)
- IMDb rating
- Rotten Tomatoes score
- Metascore
- Rated (MPAA rating: PG, R, etc.)

---

## Media Types

Movies and TV shows are both supported. The media type is stored alongside the movie record and affects how metadata is displayed (e.g., episode count for TV, runtime for films).

---

## Movie Enrichment

When movies are imported from a backup file, they arrive as stubs (IMDb ID + user data only, no TMDB/OMDb metadata). The import response includes `imdb_ids_needing_enrichment`. The client then calls:

```
GET /api/movies/{imdb_id}/refresh
```

for each stub in the background to fetch and store the full metadata. This keeps backup files compact while still allowing full restoration.

---

## Custom Lists

Movies can be assigned to custom lists in addition to their status. Custom lists have:
- Name
- Color (hex)
- Icon (SF Symbol name on iOS; emoji/icon on web)
- Sort position

A movie in a custom list still has its primary status (`toWatch`, `watched`, etc.). Lists are a secondary organizational layer.

---

## Related Docs

- [People & Recommenders](people.md)
- [Backup & Export](backup-export.md)
- [API Reference](../reference/api.md)
- [Database Schema](../reference/database-schema.md)
