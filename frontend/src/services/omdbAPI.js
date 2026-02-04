/**
 * OMDb API integration
 * Fetches additional movie data and ratings from OMDb
 */

const OMDB_API_KEY = import.meta.env.VITE_OMDB_API_KEY;
const OMDB_BASE_URL = 'https://www.omdbapi.com';

/**
 * Get movie details from OMDb by IMDb ID
 */
export async function getMovieByImdbId(imdbId) {
  if (!OMDB_API_KEY) {
    throw new Error('OMDb API key not configured');
  }

  const url = `${OMDB_BASE_URL}/?apikey=${OMDB_API_KEY}&i=${imdbId}`;

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`OMDb API error: ${response.status}`);
    }

    const data = await response.json();

    if (data.Response === 'False') {
      throw new Error(data.Error || 'Movie not found');
    }

    // Parse Rotten Tomatoes rating
    let rtRating = null;
    const rtRatingObj = data.Ratings?.find(r => r.Source === 'Rotten Tomatoes');
    if (rtRatingObj) {
      rtRating = parseInt(rtRatingObj.Value.replace('%', ''), 10);
    }

    return {
      imdbId: data.imdbID,
      title: data.Title,
      year: parseInt(data.Year, 10),
      rated: data.Rated,
      released: data.Released,
      runtime: data.Runtime,
      genres: data.Genre?.split(', ') || [],
      director: data.Director,
      writer: data.Writer,
      actors: data.Actors?.split(', ') || [],
      plot: data.Plot,
      language: data.Language,
      country: data.Country,
      awards: data.Awards,
      poster: data.Poster !== 'N/A' ? data.Poster : null,
      imdbRating: parseFloat(data.imdbRating) || null,
      imdbVotes: data.imdbVotes,
      rtRating,
      metascore: data.Metascore !== 'N/A' ? parseInt(data.Metascore, 10) : null,
      boxOffice: data.BoxOffice,
      production: data.Production,
      website: data.Website,
    };
  } catch (error) {
    console.error('Error fetching from OMDb:', error);
    throw error;
  }
}

/**
 * Search for movies on OMDb (limited to 10 results)
 */
export async function searchMovies(query) {
  if (!OMDB_API_KEY) {
    throw new Error('OMDb API key not configured');
  }

  const url = `${OMDB_BASE_URL}/?apikey=${OMDB_API_KEY}&s=${encodeURIComponent(query)}`;

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`OMDb API error: ${response.status}`);
    }

    const data = await response.json();

    if (data.Response === 'False') {
      return [];
    }

    return data.Search.map(movie => ({
      imdbId: movie.imdbID,
      title: movie.Title,
      year: parseInt(movie.Year, 10),
      type: movie.Type,
      poster: movie.Poster !== 'N/A' ? movie.Poster : null,
    }));
  } catch (error) {
    console.error('Error searching OMDb:', error);
    throw error;
  }
}
