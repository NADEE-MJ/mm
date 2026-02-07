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
  try {
    const results = await api.searchTMDB(query);
    // Results are already formatted by the backend
    return results;
  } catch (error) {
    console.error('Error searching TMDB:', error);
    throw error;
  }
}

/**
 * Get movie details from TMDB by ID via backend proxy
 */
export async function getMovieDetails(tmdbId) {
  try {
    const movie = await api.getTMDBMovieDetails(tmdbId);
    // Movie details are already formatted by the backend
    return movie;
  } catch (error) {
    console.error('Error getting TMDB movie details:', error);
    throw error;
  }
}

/**
 * Get poster URL from path
 */
export function getPosterUrl(path, size = 'w500') {
  if (!path) return null;
  return `${TMDB_IMAGE_BASE}/${size}${path}`;
}
