/**
 * TMDB API integration (via backend proxy)
 * Handles movie search and data fetching from The Movie Database
 */

import api from "./api";

const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';

/**
 * Search for movies on TMDB via backend proxy
 */
export async function searchMovies(query) {
  return api.searchTMDB(query);
}

/**
 * Get movie details from TMDB by ID via backend proxy
 */
export async function getMovieDetails(tmdbId) {
  return api.getTMDBMovieDetails(tmdbId);
}

/**
 * Get TV show details from TMDB by ID via backend proxy
 */
export async function getTVDetails(tmdbId) {
  return api.getTMDBTVDetails(tmdbId);
}

/**
 * Get poster URL from path
 */
export function getPosterUrl(path, size = 'w500') {
  if (!path) return null;
  return `${TMDB_IMAGE_BASE}/${size}${path}`;
}
