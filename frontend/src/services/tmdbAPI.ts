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
 * Discover movies by genre name via backend proxy (TMDB discover, sorted by popularity)
 */
export async function discoverByGenre(genre) {
  return api.discoverTMDBByGenre(genre);
}

/**
 * Discover movies by actor/director name via backend proxy
 */
export async function discoverByPerson(name, role = "actor") {
  return api.discoverTMDBByPerson(name, role);
}

/**
 * Discover movies by production company name via backend proxy
 */
export async function discoverByCompany(name) {
  return api.discoverTMDBByCompany(name);
}

/**
 * Discover a curated TMDB list (popular, top_rated, trending, coming_soon, now_playing)
 */
export async function discoverList(kind) {
  return api.discoverTMDBList(kind);
}

/**
 * Get "For You" recommendations based on movies/shows the user has upvoted
 */
export async function getRecommendationsForYou(limit = 30) {
  return api.getRecommendationsForYou(limit);
}

/**
 * Get poster URL from path
 */
export function getPosterUrl(path, size = 'w500') {
  if (!path) return null;
  return `${TMDB_IMAGE_BASE}/${size}${path}`;
}
