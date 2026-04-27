# Movies

Movies (and TV entries) are the core records in Movie Manager.
Each item tracks:
- status
- recommendations (who suggested it)
- optional watch history + rating

## Add Flow

### Web

1. Open Add Movie modal.
2. Search via TMDB-backed backend endpoint.
3. Select one or more recommenders.
4. Submit recommendation.

### iOS

1. Open the Discover tab.
2. Search title.
3. Select recommenders.
4. Save.

## Status Model

| Status | Meaning |
|---|---|
| `toWatch` | Default queue |
| `watched` | Has been watched/rated |
| `custom` | Assigned to custom list |
| `deleted` | Soft-removed from active views |

## Watching and Rating

- `PUT /api/movies/{imdb_id}/watch` stores `date_watched` and `my_rating`.
- Ratings are `1.0` to `10.0`.
- Rewatch updates the same watch-history record.

## Recommendations

- One recommendation row per `(movie, person)`.
- Vote type supports upvote/downvote.
- Recommenders can be regular people or quick recommenders (`quick_key`).

## Media Types

`media_type` supports both:
- `movie`
- `tv`

## Metadata Sources

Backend enriches entries using:
- TMDB (title, poster, credits, etc.)
- OMDb (IMDb/RT/Metascore ratings)

If an import creates metadata stubs, clients can enrich with:

```text
POST /api/movies/{imdb_id}/refresh
```

## Related Docs

- [People & Recommenders](people.md)
- [Backup and Export](backup-export.md)
- [API Reference](../reference/api.md)
- [Database Schema](../reference/database-schema.md)
