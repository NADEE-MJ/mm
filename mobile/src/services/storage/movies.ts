import { getDatabase } from '../database/init';
import {
  Movie,
  MovieWithDetails,
  Recommendation,
  WatchHistory,
  MovieStatus,
  TMDBData,
  OMDBData,
} from '../../types';

/**
 * Get all movies with their related data
 */
export async function getAllMovies(): Promise<MovieWithDetails[]> {
  try {
    const db = getDatabase();

    const movies = await db.getAllAsync<any>(
      'SELECT * FROM movies ORDER BY last_modified DESC'
    );

    const moviesWithDetails = await Promise.all(
      movies.map(async (movie) => {
        const recommendations = await getMovieRecommendations(movie.imdb_id);
        const watch_history = await getWatchHistory(movie.imdb_id);
        const status = await getMovieStatus(movie.imdb_id);

        return {
          ...movie,
          tmdb_data: movie.tmdb_data ? JSON.parse(movie.tmdb_data) : undefined,
          omdb_data: movie.omdb_data ? JSON.parse(movie.omdb_data) : undefined,
          recommendations,
          watch_history,
          status: status || {
            imdb_id: movie.imdb_id,
            user_id: movie.user_id,
            status: 'toWatch',
          },
        };
      })
    );

    return moviesWithDetails;
  } catch (error) {
    console.error('Failed to get all movies:', error);
    return [];
  }
}

/**
 * Get a single movie by IMDb ID
 */
export async function getMovie(imdbId: string): Promise<MovieWithDetails | null> {
  try {
    const db = getDatabase();

    const movie = await db.getFirstAsync<any>(
      'SELECT * FROM movies WHERE imdb_id = ?',
      [imdbId]
    );

    if (!movie) {
      return null;
    }

    const recommendations = await getMovieRecommendations(imdbId);
    const watch_history = await getWatchHistory(imdbId);
    const status = await getMovieStatus(imdbId);

    return {
      ...movie,
      tmdb_data: movie.tmdb_data ? JSON.parse(movie.tmdb_data) : undefined,
      omdb_data: movie.omdb_data ? JSON.parse(movie.omdb_data) : undefined,
      recommendations,
      watch_history,
      status: status || {
        imdb_id: movie.imdb_id,
        user_id: movie.user_id,
        status: 'toWatch',
      },
    };
  } catch (error) {
    console.error('Failed to get movie:', error);
    return null;
  }
}

/**
 * Add or update a movie
 */
export async function saveMovie(
  imdbId: string,
  userId: string,
  tmdbData?: TMDBData,
  omdbData?: OMDBData
): Promise<void> {
  try {
    const db = getDatabase();
    const now = Date.now();

    await db.runAsync(
      `INSERT OR REPLACE INTO movies (imdb_id, user_id, tmdb_data, omdb_data, last_modified)
       VALUES (?, ?, ?, ?, ?)`,
      [
        imdbId,
        userId,
        tmdbData ? JSON.stringify(tmdbData) : null,
        omdbData ? JSON.stringify(omdbData) : null,
        now,
      ]
    );

    // Initialize movie status if it doesn't exist
    const existingStatus = await getMovieStatus(imdbId);
    if (!existingStatus) {
      await setMovieStatus(imdbId, userId, 'toWatch');
    }
  } catch (error) {
    console.error('Failed to save movie:', error);
    throw error;
  }
}

/**
 * Delete a movie
 */
export async function deleteMovie(imdbId: string): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync('DELETE FROM movies WHERE imdb_id = ?', [imdbId]);
  } catch (error) {
    console.error('Failed to delete movie:', error);
    throw error;
  }
}

/**
 * Get movie recommendations
 */
export async function getMovieRecommendations(imdbId: string): Promise<Recommendation[]> {
  try {
    const db = getDatabase();
    const recommendations = await db.getAllAsync<Recommendation>(
      'SELECT * FROM recommendations WHERE imdb_id = ? ORDER BY date_recommended DESC',
      [imdbId]
    );
    return recommendations;
  } catch (error) {
    console.error('Failed to get recommendations:', error);
    return [];
  }
}

/**
 * Add a recommendation
 */
export async function addRecommendation(
  imdbId: string,
  userId: string,
  person: string,
  voteType: 'upvote' | 'downvote' = 'upvote'
): Promise<void> {
  try {
    const db = getDatabase();
    const now = Date.now();

    await db.runAsync(
      `INSERT OR REPLACE INTO recommendations (imdb_id, user_id, person, date_recommended, vote_type)
       VALUES (?, ?, ?, ?, ?)`,
      [imdbId, userId, person, now, voteType]
    );
  } catch (error) {
    console.error('Failed to add recommendation:', error);
    throw error;
  }
}

/**
 * Update recommendation vote type
 */
export async function updateRecommendationVote(
  imdbId: string,
  person: string,
  voteType: 'upvote' | 'downvote'
): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      'UPDATE recommendations SET vote_type = ? WHERE imdb_id = ? AND person = ?',
      [voteType, imdbId, person]
    );
  } catch (error) {
    console.error('Failed to update recommendation vote:', error);
    throw error;
  }
}

/**
 * Remove a recommendation
 */
export async function removeRecommendation(
  imdbId: string,
  person: string
): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      'DELETE FROM recommendations WHERE imdb_id = ? AND person = ?',
      [imdbId, person]
    );
  } catch (error) {
    console.error('Failed to remove recommendation:', error);
    throw error;
  }
}

/**
 * Get watch history for a movie
 */
export async function getWatchHistory(imdbId: string): Promise<WatchHistory | undefined> {
  try {
    const db = getDatabase();
    const history = await db.getFirstAsync<WatchHistory>(
      'SELECT * FROM watch_history WHERE imdb_id = ?',
      [imdbId]
    );
    return history || undefined;
  } catch (error) {
    console.error('Failed to get watch history:', error);
    return undefined;
  }
}

/**
 * Mark movie as watched with rating
 */
export async function markAsWatched(
  imdbId: string,
  userId: string,
  rating: number
): Promise<void> {
  try {
    const db = getDatabase();
    const now = Date.now();

    await db.runAsync(
      `INSERT OR REPLACE INTO watch_history (imdb_id, user_id, date_watched, my_rating)
       VALUES (?, ?, ?, ?)`,
      [imdbId, userId, now, rating]
    );

    // Update movie status to watched
    await setMovieStatus(imdbId, userId, 'watched');
  } catch (error) {
    console.error('Failed to mark as watched:', error);
    throw error;
  }
}

/**
 * Update rating for a watched movie
 */
export async function updateRating(imdbId: string, rating: number): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      'UPDATE watch_history SET my_rating = ? WHERE imdb_id = ?',
      [rating, imdbId]
    );
  } catch (error) {
    console.error('Failed to update rating:', error);
    throw error;
  }
}

/**
 * Get movie status
 */
export async function getMovieStatus(imdbId: string): Promise<MovieStatus | null> {
  try {
    const db = getDatabase();
    const status = await db.getFirstAsync<MovieStatus>(
      'SELECT * FROM movie_status WHERE imdb_id = ?',
      [imdbId]
    );
    return status || null;
  } catch (error) {
    console.error('Failed to get movie status:', error);
    return null;
  }
}

/**
 * Set movie status
 */
export async function setMovieStatus(
  imdbId: string,
  userId: string,
  status: 'toWatch' | 'watched' | 'deleted' | 'custom',
  customListId?: string
): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      `INSERT OR REPLACE INTO movie_status (imdb_id, user_id, status, custom_list_id)
       VALUES (?, ?, ?, ?)`,
      [imdbId, userId, status, customListId || null]
    );
  } catch (error) {
    console.error('Failed to set movie status:', error);
    throw error;
  }
}

/**
 * Search movies by title (local search)
 */
export async function searchMovies(query: string): Promise<MovieWithDetails[]> {
  try {
    const allMovies = await getAllMovies();
    const lowerQuery = query.toLowerCase();

    return allMovies.filter((movie) => {
      const title = movie.tmdb_data?.title?.toLowerCase() || '';
      return title.includes(lowerQuery);
    });
  } catch (error) {
    console.error('Failed to search movies:', error);
    return [];
  }
}

/**
 * Get movies by status
 */
export async function getMoviesByStatus(
  status: 'toWatch' | 'watched' | 'deleted' | 'custom'
): Promise<MovieWithDetails[]> {
  try {
    const db = getDatabase();

    const movies = await db.getAllAsync<any>(
      `SELECT m.* FROM movies m
       JOIN movie_status ms ON m.imdb_id = ms.imdb_id
       WHERE ms.status = ?
       ORDER BY m.last_modified DESC`,
      [status]
    );

    const moviesWithDetails = await Promise.all(
      movies.map(async (movie) => {
        const recommendations = await getMovieRecommendations(movie.imdb_id);
        const watch_history = await getWatchHistory(movie.imdb_id);
        const movieStatus = await getMovieStatus(movie.imdb_id);

        return {
          ...movie,
          tmdb_data: movie.tmdb_data ? JSON.parse(movie.tmdb_data) : undefined,
          omdb_data: movie.omdb_data ? JSON.parse(movie.omdb_data) : undefined,
          recommendations,
          watch_history,
          status: movieStatus || {
            imdb_id: movie.imdb_id,
            user_id: movie.user_id,
            status: 'toWatch',
          },
        };
      })
    );

    return moviesWithDetails;
  } catch (error) {
    console.error('Failed to get movies by status:', error);
    return [];
  }
}
