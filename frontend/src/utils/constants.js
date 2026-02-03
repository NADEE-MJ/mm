/**
 * Constants used throughout the application
 */

export const MOVIE_STATUS = {
  TO_WATCH: 'toWatch',
  WATCHED: 'watched',
  QUESTIONABLE: 'questionable',
  DELETED: 'deleted',
};

export const SYNC_STATUS = {
  SYNCED: 'synced',
  PENDING: 'pending',
  CONFLICT: 'conflict',
  OFFLINE: 'offline',
};

export const RATING_THRESHOLD = 6.0; // Threshold for triggering questionable prompt

export const API_LIMITS = {
  TMDB_RATE_LIMIT: 40, // 40 requests per second
  OMDB_DAILY_LIMIT: 1000, // 1000 requests per day
};

export const POSTER_PLACEHOLDER = 'https://via.placeholder.com/500x750?text=No+Poster';
