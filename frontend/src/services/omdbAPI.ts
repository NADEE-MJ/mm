/**
 * OMDb API integration (via backend proxy)
 * Fetches additional movie data and ratings from OMDb
 */

import api from "./api";

/**
 * Get movie details from OMDb by IMDb ID via backend proxy
 */
export async function getMovieByImdbId(imdbId) {
  try {
    const movie = await api.getOMDBMovie(imdbId);
    // Movie details are already formatted by the backend
    return movie;
  } catch (error) {
    console.error('Error fetching from OMDb:', error);
    throw error;
  }
}
