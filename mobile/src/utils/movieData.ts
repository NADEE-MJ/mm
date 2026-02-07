import { MovieWithDetails } from '../types';

function tmdb(movie: MovieWithDetails): any {
  return movie.tmdb_data || {};
}

function omdb(movie: MovieWithDetails): any {
  return movie.omdb_data || {};
}

export function getMovieTitle(movie: MovieWithDetails): string {
  const t = tmdb(movie);
  const o = omdb(movie);
  return t.title || o.title || o.Title || 'Unknown Title';
}

export function getMovieYear(movie: MovieWithDetails): string {
  const t = tmdb(movie);
  const o = omdb(movie);
  const year =
    t.year ||
    (typeof t.release_date === 'string' ? t.release_date.slice(0, 4) : undefined) ||
    o.year ||
    o.Year;
  return year ? String(year) : 'N/A';
}

export function getPosterUrl(movie: MovieWithDetails): string | null {
  const t = tmdb(movie);
  const o = omdb(movie);

  if (t.poster) return t.poster;
  if (t.posterSmall) return t.posterSmall;
  if (t.poster_path) return `https://image.tmdb.org/t/p/w500${t.poster_path}`;
  if (o.poster) return o.poster;
  if (o.Poster && o.Poster !== 'N/A') return o.Poster;
  return null;
}

export function getBackdropUrl(movie: MovieWithDetails): string | null {
  const t = tmdb(movie);
  if (t.backdrop) return t.backdrop;
  if (t.backdrop_path) return `https://image.tmdb.org/t/p/original${t.backdrop_path}`;
  return null;
}

export function getMovieVoteAverage(movie: MovieWithDetails): number | null {
  const t = tmdb(movie);
  const o = omdb(movie);
  const value = t.voteAverage ?? t.vote_average ?? o.imdbRating;
  if (value === undefined || value === null || value === '') return null;
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
}

export function getMovieRuntime(movie: MovieWithDetails): string | null {
  const t = tmdb(movie);
  const o = omdb(movie);
  if (t.runtime) return `${t.runtime} min`;
  if (o.runtime) return String(o.runtime);
  if (o.Runtime && o.Runtime !== 'N/A') return o.Runtime;
  return null;
}

export function getMovieOverview(movie: MovieWithDetails): string | null {
  const t = tmdb(movie);
  const o = omdb(movie);
  return t.plot || t.overview || o.plot || o.Plot || null;
}

export function getMovieTagline(movie: MovieWithDetails): string | null {
  const t = tmdb(movie);
  return t.tagline || null;
}

export function getMovieGenres(movie: MovieWithDetails): string[] {
  const t = tmdb(movie);
  const o = omdb(movie);

  if (Array.isArray(t.genres) && t.genres.length > 0) {
    return t.genres
      .map((genre: any) =>
        typeof genre === 'string' ? genre : genre?.name || genre?.title
      )
      .filter(Boolean);
  }

  if (Array.isArray(o.genres) && o.genres.length > 0) {
    return o.genres.filter(Boolean);
  }

  if (typeof o.Genre === 'string' && o.Genre.trim().length > 0) {
    return o.Genre.split(',').map((genre: string) => genre.trim()).filter(Boolean);
  }

  return [];
}

