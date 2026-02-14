/**
 * Helper utility functions
 */

import { POSTER_PLACEHOLDER } from "./constants";

/**
 * Format date to readable string
 */
export function formatDate(timestamp) {
  if (!timestamp) return "";
  const date = new Date(timestamp);
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

/**
 * Format rating to 1 decimal place
 */
export function formatRating(rating) {
  if (!rating && rating !== 0) return "N/A";
  return rating.toFixed(1);
}

/**
 * Get poster URL or placeholder
 */
export function getPoster(posterUrl) {
  const normalizedPoster = String(posterUrl || "").trim();

  if (!normalizedPoster || normalizedPoster.toUpperCase() === "N/A") {
    return POSTER_PLACEHOLDER;
  }

  if (normalizedPoster.startsWith("//")) {
    return `https:${normalizedPoster}`;
  }

  if (normalizedPoster.startsWith("http://")) {
    return `https://${normalizedPoster.slice("http://".length)}`;
  }

  return normalizedPoster;
}

/**
 * Sort movies by various criteria
 */
export function sortMovies(movies, sortBy) {
  const sorted = [...movies];

  switch (sortBy) {
    case "dateRecommended":
      return sorted.sort((a, b) => {
        const aDate = Math.max(...(a.recommendations?.map((r) => r.date_recommended) || [0]));
        const bDate = Math.max(...(b.recommendations?.map((r) => r.date_recommended) || [0]));
        return bDate - aDate;
      });

    case "dateWatched":
      return sorted.sort((a, b) => {
        const aDate = a.watchHistory?.dateWatched || 0;
        const bDate = b.watchHistory?.dateWatched || 0;
        return bDate - aDate;
      });

    case "myRating":
      return sorted.sort((a, b) => {
        const aRating = a.watchHistory?.myRating || 0;
        const bRating = b.watchHistory?.myRating || 0;
        return bRating - aRating;
      });

    case "imdbRating":
      return sorted.sort((a, b) => {
        const aRating = a.omdbData?.imdbRating || 0;
        const bRating = b.omdbData?.imdbRating || 0;
        return bRating - aRating;
      });

    case "year":
      return sorted.sort((a, b) => {
        const aYear = a.omdbData?.year || a.tmdbData?.year || 0;
        const bYear = b.omdbData?.year || b.tmdbData?.year || 0;
        return bYear - aYear;
      });

    case "title":
      return sorted.sort((a, b) => {
        const aTitle = a.omdbData?.title || a.tmdbData?.title || "";
        const bTitle = b.omdbData?.title || b.tmdbData?.title || "";
        return aTitle.localeCompare(bTitle);
      });

    default:
      return sorted;
  }
}

/**
 * Filter movies by various criteria
 */
export function filterMovies(movies, filters) {
  let filtered = [...movies];

  const searchTerm = filters.search?.trim().toLowerCase();

  // Filter by recommender
  if (filters.recommender) {
    filtered = filtered.filter((m) =>
      m.recommendations?.some((r) => r.person === filters.recommender),
    );
  }

  if (filters.mediaType && filters.mediaType !== "all") {
    filtered = filtered.filter((m) => (m.mediaType || "movie") === filters.mediaType);
  }

  // Search across title, genres, cast, and director/writer metadata
  if (searchTerm) {
    filtered = filtered.filter((movie) => {
      const tmdb = movie.tmdbData || {};
      const omdb = movie.omdbData || {};

      const searchableFields = [
        omdb.title,
        tmdb.title,
        (omdb.genres || []).join(" "),
        (tmdb.genres || []).join(" "),
        (omdb.actors || []).join(" "),
        (tmdb.cast || []).join(" "),
        omdb.director,
        omdb.writer,
      ]
        .filter(Boolean)
        .map((value) => value.toLowerCase());

      return searchableFields.some((field) => field.includes(searchTerm));
    });
  }

  // Filter by genre
  if (filters.genre) {
    filtered = filtered.filter((m) => {
      const genres = m.omdbData?.genres || m.tmdbData?.genres || [];
      return genres.includes(filters.genre);
    });
  }

  // Filter by decade
  if (filters.decade) {
    filtered = filtered.filter((m) => {
      const year = m.omdbData?.year || m.tmdbData?.year;
      if (!year) return false;
      const decade = Math.floor(year / 10) * 10;
      return decade === parseInt(filters.decade, 10);
    });
  }

  return filtered;
}

/**
 * Get all unique genres from movies
 */
export function getGenres(movies) {
  const genresSet = new Set();
  movies.forEach((movie) => {
    const genres = movie.omdbData?.genres || movie.tmdbData?.genres || [];
    genres.forEach((genre) => genresSet.add(genre));
  });
  return Array.from(genresSet).sort();
}

/**
 * Get all unique decades from movies
 */
export function getDecades(movies) {
  const decadesSet = new Set();
  movies.forEach((movie) => {
    const year = movie.omdbData?.year || movie.tmdbData?.year;
    if (year) {
      const decade = Math.floor(year / 10) * 10;
      decadesSet.add(decade);
    }
  });
  return Array.from(decadesSet).sort((a, b) => b - a);
}

/**
 * Get all unique recommenders from movies
 */
export function getAllRecommenders(movies) {
  const recommendersSet = new Set();
  movies.forEach((movie) => {
    movie.recommendations?.forEach((r) => recommendersSet.add(r.person));
  });
  return Array.from(recommendersSet).sort();
}
