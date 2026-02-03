/**
 * TMDB API integration
 * Handles movie search and data fetching from The Movie Database
 */

const TMDB_API_KEY = import.meta.env.VITE_TMDB_API_KEY;
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';

/**
 * Search for movies on TMDB
 */
export async function searchMovies(query) {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB API key not configured');
  }

  const url = `${TMDB_BASE_URL}/search/movie?api_key=${TMDB_API_KEY}&query=${encodeURIComponent(query)}`;

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`TMDB API error: ${response.status}`);
    }

    const data = await response.json();
    return data.results.map(movie => ({
      id: movie.id,
      title: movie.title,
      year: movie.release_date ? new Date(movie.release_date).getFullYear() : null,
      poster: movie.poster_path ? `${TMDB_IMAGE_BASE}/w500${movie.poster_path}` : null,
      posterSmall: movie.poster_path ? `${TMDB_IMAGE_BASE}/w200${movie.poster_path}` : null,
      overview: movie.overview,
      voteAverage: movie.vote_average,
      voteCount: movie.vote_count,
    }));
  } catch (error) {
    console.error('Error searching TMDB:', error);
    throw error;
  }
}

/**
 * Get movie details from TMDB by ID
 */
export async function getMovieDetails(tmdbId) {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB API key not configured');
  }

  const url = `${TMDB_BASE_URL}/movie/${tmdbId}?api_key=${TMDB_API_KEY}&append_to_response=credits,external_ids`;

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`TMDB API error: ${response.status}`);
    }

    const movie = await response.json();

    return {
      tmdbId: movie.id,
      imdbId: movie.external_ids?.imdb_id || null,
      title: movie.title,
      year: movie.release_date ? new Date(movie.release_date).getFullYear() : null,
      poster: movie.poster_path ? `${TMDB_IMAGE_BASE}/w500${movie.poster_path}` : null,
      posterSmall: movie.poster_path ? `${TMDB_IMAGE_BASE}/w200${movie.poster_path}` : null,
      plot: movie.overview,
      genres: movie.genres.map(g => g.name),
      cast: movie.credits?.cast?.slice(0, 10).map(c => c.name) || [],
      runtime: movie.runtime,
      voteAverage: movie.vote_average,
      voteCount: movie.vote_count,
    };
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
