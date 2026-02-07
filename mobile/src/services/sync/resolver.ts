import { getDatabase } from '../database/init';
import { ServerSyncData, Movie, Recommendation, WatchHistory, MovieStatus, Person, CustomList } from '../../types';

/**
 * Apply server sync data to local database
 * Uses last_modified timestamp to resolve conflicts
 */
export async function applySyncData(serverData: ServerSyncData): Promise<void> {
  const db = getDatabase();

  try {
    // Start transaction for atomic updates
    await db.execAsync('BEGIN TRANSACTION');

    // Apply movies (with null safety)
    if (serverData.movies && Array.isArray(serverData.movies)) {
      for (const movie of serverData.movies) {
        await applyMovie(db, movie);
      }
    }

    // Apply recommendations (with null safety)
    if (serverData.recommendations && Array.isArray(serverData.recommendations)) {
      for (const rec of serverData.recommendations) {
        await applyRecommendation(db, rec);
      }
    }

    // Apply watch history (with null safety)
    if (serverData.watch_history && Array.isArray(serverData.watch_history)) {
      for (const history of serverData.watch_history) {
        await applyWatchHistory(db, history);
      }
    }

    // Apply movie status (with null safety)
    if (serverData.movie_status && Array.isArray(serverData.movie_status)) {
      for (const status of serverData.movie_status) {
        await applyMovieStatus(db, status);
      }
    }

    // Apply people (with null safety)
    if (serverData.people && Array.isArray(serverData.people)) {
      for (const person of serverData.people) {
        await applyPerson(db, person);
      }
    }

    // Apply custom lists (with null safety)
    if (serverData.custom_lists && Array.isArray(serverData.custom_lists)) {
      for (const list of serverData.custom_lists) {
        await applyCustomList(db, list);
      }
    }

    // Commit transaction
    await db.execAsync('COMMIT');

    console.log('Server sync data applied successfully');
  } catch (error) {
    // Rollback on error
    await db.execAsync('ROLLBACK');
    console.error('Failed to apply sync data:', error);
    throw error;
  }
}

/**
 * Apply movie with conflict resolution (last_modified wins)
 */
async function applyMovie(db: any, serverMovie: Movie): Promise<void> {
  // Check if local movie exists
  const localMovie = await db.getFirstAsync<{ last_modified: number }>(
    'SELECT last_modified FROM movies WHERE imdb_id = ?',
    [serverMovie.imdb_id]
  );

  // If local doesn't exist or server is newer, apply server version
  if (!localMovie || serverMovie.last_modified > localMovie.last_modified) {
    await db.runAsync(
      `INSERT OR REPLACE INTO movies (imdb_id, user_id, tmdb_data, omdb_data, last_modified)
       VALUES (?, ?, ?, ?, ?)`,
      [
        serverMovie.imdb_id,
        serverMovie.user_id,
        serverMovie.tmdb_data ? JSON.stringify(serverMovie.tmdb_data) : null,
        serverMovie.omdb_data ? JSON.stringify(serverMovie.omdb_data) : null,
        serverMovie.last_modified,
      ]
    );

    console.log(`Applied server movie: ${serverMovie.imdb_id}`);
  } else {
    console.log(`Skipped movie ${serverMovie.imdb_id} - local is newer`);
  }
}

/**
 * Apply recommendation
 */
async function applyRecommendation(db: any, rec: Recommendation): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO recommendations (id, imdb_id, user_id, person, date_recommended, vote_type)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [
      rec.id,
      rec.imdb_id,
      rec.user_id,
      rec.person,
      rec.date_recommended,
      rec.vote_type,
    ]
  );
}

/**
 * Apply watch history
 */
async function applyWatchHistory(db: any, history: WatchHistory): Promise<void> {
  // Check if local watch history exists
  const localHistory = await db.getFirstAsync<{ date_watched: number }>(
    'SELECT date_watched FROM watch_history WHERE imdb_id = ?',
    [history.imdb_id]
  );

  // If local doesn't exist or server is newer, apply server version
  if (!localHistory || history.date_watched > localHistory.date_watched) {
    await db.runAsync(
      `INSERT OR REPLACE INTO watch_history (imdb_id, user_id, date_watched, my_rating)
       VALUES (?, ?, ?, ?)`,
      [
        history.imdb_id,
        history.user_id,
        history.date_watched,
        history.my_rating,
      ]
    );

    console.log(`Applied watch history: ${history.imdb_id}`);
  }
}

/**
 * Apply movie status
 */
async function applyMovieStatus(db: any, status: MovieStatus): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO movie_status (imdb_id, user_id, status, custom_list_id)
     VALUES (?, ?, ?, ?)`,
    [
      status.imdb_id,
      status.user_id,
      status.status,
      status.custom_list_id || null,
    ]
  );
}

/**
 * Apply person
 */
async function applyPerson(db: any, person: Person): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO people (name, user_id, is_trusted, is_default, color, emoji)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [
      person.name,
      person.user_id,
      person.is_trusted ? 1 : 0,
      person.is_default ? 1 : 0,
      person.color,
      person.emoji || null,
    ]
  );
}

/**
 * Apply custom list
 */
async function applyCustomList(db: any, list: CustomList): Promise<void> {
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

/**
 * Handle conflict resolution manually
 * Returns true if server wins, false if local wins
 */
export function shouldApplyServerChange(
  serverTimestamp: number,
  localTimestamp: number
): boolean {
  // Last-modified wins
  return serverTimestamp > localTimestamp;
}
