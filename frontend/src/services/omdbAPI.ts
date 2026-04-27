/**
 * OMDb API integration (via backend proxy)
 * Fetches additional movie data and ratings from OMDb
 */

import api from "./api";

/**
 * Get movie details from OMDb by IMDb ID via backend proxy
 */
export async function getMovieByImdbId(imdbId) {
  return api.getOMDBMovie(imdbId);
}
