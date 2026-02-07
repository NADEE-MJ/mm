import { getDatabase } from '../database/init';
import { ServerSyncData } from '../../types';

function toLocalTimestamp(serverSeconds?: number): number {
  if (!serverSeconds) return Date.now();
  return Math.round(serverSeconds * 1000);
}

export async function applySyncData(serverData: ServerSyncData): Promise<void> {
  const db = getDatabase();

  try {
    await db.execAsync('BEGIN TRANSACTION');

    for (const serverMovie of serverData.movies || []) {
      await applyMovie(db, serverMovie);
    }

    for (const person of serverData.people || []) {
      await db.runAsync(
        `INSERT OR REPLACE INTO people (name, user_id, is_trusted, is_default, color, emoji)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          person.name,
          person.user_id,
          person.is_trusted ? 1 : 0,
          person.is_default ? 1 : 0,
          person.color || '#0a84ff',
          person.emoji || null,
        ]
      );
    }

    for (const list of serverData.lists || []) {
      await db.runAsync(
        `INSERT OR REPLACE INTO custom_lists (id, user_id, name, color, icon, position, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          list.id,
          list.user_id,
          list.name,
          list.color,
          list.icon,
          list.position,
          list.created_at,
        ]
      );
    }

    for (const imdbId of serverData.deleted_movie_ids || []) {
      await db.runAsync(
        `UPDATE movie_status
         SET status = 'deleted', custom_list_id = NULL
         WHERE imdb_id = ?`,
        [imdbId]
      );
    }

    await db.execAsync('COMMIT');
  } catch (error) {
    await db.execAsync('ROLLBACK');
    console.error('Failed to apply sync data:', error);
    throw error;
  }
}

async function applyMovie(db: any, serverMovie: any): Promise<void> {
  const localMovie = (await db.getFirstAsync(
    'SELECT last_modified FROM movies WHERE imdb_id = ?',
    [serverMovie.imdb_id]
  )) as { last_modified: number } | null;

  const incomingLastModified = toLocalTimestamp(serverMovie.last_modified);
  if (localMovie && localMovie.last_modified > incomingLastModified) {
    return;
  }

  await db.runAsync(
    `INSERT OR REPLACE INTO movies (imdb_id, user_id, tmdb_data, omdb_data, last_modified)
     VALUES (?, ?, ?, ?, ?)`,
    [
      serverMovie.imdb_id,
      serverMovie.user_id,
      serverMovie.tmdb_data ? JSON.stringify(serverMovie.tmdb_data) : null,
      serverMovie.omdb_data ? JSON.stringify(serverMovie.omdb_data) : null,
      incomingLastModified,
    ]
  );

  await db.runAsync('DELETE FROM recommendations WHERE imdb_id = ?', [serverMovie.imdb_id]);
  for (const rec of serverMovie.recommendations || []) {
    await db.runAsync(
      `INSERT OR REPLACE INTO recommendations (id, imdb_id, user_id, person, date_recommended, vote_type)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        rec.id,
        serverMovie.imdb_id,
        rec.user_id || serverMovie.user_id,
        rec.person,
        rec.date_recommended,
        rec.vote_type || 'upvote',
      ]
    );
  }

  if (serverMovie.watch_history) {
    await db.runAsync(
      `INSERT OR REPLACE INTO watch_history (imdb_id, user_id, date_watched, my_rating)
       VALUES (?, ?, ?, ?)`,
      [
        serverMovie.imdb_id,
        serverMovie.watch_history.user_id || serverMovie.user_id,
        serverMovie.watch_history.date_watched,
        serverMovie.watch_history.my_rating,
      ]
    );
  }

  await db.runAsync(
    `INSERT OR REPLACE INTO movie_status (imdb_id, user_id, status, custom_list_id)
     VALUES (?, ?, ?, ?)`,
    [
      serverMovie.imdb_id,
      serverMovie.user_id,
      serverMovie.status || 'toWatch',
      null,
    ]
  );
}
