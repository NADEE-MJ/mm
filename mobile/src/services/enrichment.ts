import { MovieWithDetails } from '../types';
import { getOMDBMovie, getTMDBMovie, searchTMDB } from './api/movies';
import {
  addRecommendation,
  deleteMovie,
  getMovie,
  getUnenrichedMovies,
  saveMovie,
  setMovieStatus,
} from './storage/movies';
import { addToQueue, remapQueueImdbId } from './sync/queue';

function inferMovieTitle(movie: MovieWithDetails): string | null {
  return (
    (movie.tmdb_data as any)?.title ||
    (movie.omdb_data as any)?.title ||
    (movie.omdb_data as any)?.Title ||
    null
  );
}

function inferMovieYear(movie: MovieWithDetails): number | undefined {
  const yearValue =
    (movie.tmdb_data as any)?.year ||
    (movie.omdb_data as any)?.year ||
    (movie.omdb_data as any)?.Year;
  if (!yearValue) return undefined;
  const parsed = parseInt(String(yearValue), 10);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export async function getMoviesNeedingEnrichment(): Promise<MovieWithDetails[]> {
  return getUnenrichedMovies();
}

export async function enrichMovie(movie: MovieWithDetails): Promise<MovieWithDetails> {
  const title = inferMovieTitle(movie);
  const year = inferMovieYear(movie);

  if (!title) {
    throw new Error('Movie has no title to enrich');
  }

  const searchResults = await searchTMDB(title, year);
  if (searchResults.length === 0) {
    throw new Error(`No TMDB match found for "${title}"`);
  }

  const selected = searchResults[0];
  const tmdbData = await getTMDBMovie(selected.id);
  const resolvedImdbId = tmdbData?.imdbId || movie.imdb_id;
  const omdbData = resolvedImdbId?.startsWith('tt')
    ? await getOMDBMovie(resolvedImdbId).catch(() => null)
    : null;

  const userId = movie.user_id;
  let targetImdbId = movie.imdb_id;

  if (resolvedImdbId && resolvedImdbId !== movie.imdb_id && movie.imdb_id.startsWith('temp_')) {
    // Replace temporary ids with canonical IMDb ids locally.
    await saveMovie(resolvedImdbId, userId, tmdbData, omdbData || undefined);
    for (const rec of movie.recommendations || []) {
      await addRecommendation(resolvedImdbId, userId, rec.person, rec.vote_type);
    }
    await setMovieStatus(
      resolvedImdbId,
      userId,
      movie.status.status,
      movie.status.custom_list_id
    );
    await deleteMovie(movie.imdb_id);
    await remapQueueImdbId(movie.imdb_id, resolvedImdbId);
    await addToQueue('updateStatus', { imdb_id: movie.imdb_id, status: 'deleted' });
    targetImdbId = resolvedImdbId;
  } else {
    await saveMovie(targetImdbId, userId, tmdbData, omdbData || undefined);
  }

  const primaryRecommender = movie.recommendations?.[0]?.person;
  await addToQueue('addRecommendation', {
    imdb_id: targetImdbId,
    person: primaryRecommender,
    tmdb_data: tmdbData,
    omdb_data: omdbData,
  });

  const enrichedMovie = await getMovie(targetImdbId);
  if (!enrichedMovie) {
    throw new Error('Enriched movie could not be loaded from local storage');
  }
  return enrichedMovie;
}

export async function bulkEnrich(
  movies: MovieWithDetails[],
  onProgress?: (done: number, total: number) => void
): Promise<void> {
  let completed = 0;
  for (const movie of movies) {
    try {
      await enrichMovie(movie);
    } catch (error) {
      console.warn('Enrichment failed for movie', movie.imdb_id, error);
    } finally {
      completed += 1;
      onProgress?.(completed, movies.length);
      await new Promise((resolve) => setTimeout(resolve, 750));
    }
  }
}

