import { apiClient, handleApiError } from "./client";
import { TMDBData, OMDBData, ApiResponse } from "../../types";

export interface TMDBSearchResult {
  id: number;
  title: string;
  overview: string | null;
  year: string | null;
  poster: string | null;
  posterSmall: string | null;
  voteAverage: number;
  voteCount: number;
}

/**
 * Search TMDB for movies
 */
export async function searchTMDB(query: string): Promise<TMDBSearchResult[]> {
  try {
    // Backend returns array directly, not wrapped in ApiResponse
    const response = await apiClient.get<TMDBSearchResult[]>("/external/tmdb/search", {
      params: { q: query },
    });

    return response.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Get TMDB movie details by ID
 */
export async function getTMDBMovie(tmdbId: number): Promise<any> {
  try {
    // Backend returns movie data directly, not wrapped in ApiResponse
    const response = await apiClient.get<any>(`/external/tmdb/movie/${tmdbId}`);

    return response.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Add a movie to the backend
 */
export async function addMovie(
  imdbId: string,
  tmdbData: TMDBData,
  omdbData?: OMDBData,
): Promise<void> {
  try {
    await apiClient.post("/movies", {
      imdb_id: imdbId,
      tmdb_data: tmdbData,
      omdb_data: omdbData,
    });
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Add a recommendation to a movie
 */
export async function addMovieRecommendation(
  imdbId: string,
  person: string,
  voteType: "upvote" | "downvote" = "upvote",
): Promise<void> {
  try {
    await apiClient.post(`/movies/${imdbId}/recommendations`, {
      person,
      vote_type: voteType,
    });
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Update recommendation vote type
 */
export async function updateMovieRecommendationVote(
  imdbId: string,
  person: string,
  voteType: "upvote" | "downvote",
): Promise<void> {
  try {
    await apiClient.put(`/movies/${imdbId}/recommendations/${person}`, {
      vote_type: voteType,
    });
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Remove a recommendation from a movie
 */
export async function removeMovieRecommendation(imdbId: string, person: string): Promise<void> {
  try {
    await apiClient.delete(`/movies/${imdbId}/recommendations/${person}`);
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Mark movie as watched with rating
 */
export async function markMovieAsWatched(imdbId: string, rating: number): Promise<void> {
  try {
    await apiClient.put(`/movies/${imdbId}/watch`, {
      rating,
    });
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Update movie status
 */
export async function updateMovieStatus(
  imdbId: string,
  status: "toWatch" | "watched" | "deleted" | "custom",
  customListId?: string,
): Promise<void> {
  try {
    await apiClient.put(`/movies/${imdbId}/status`, {
      status,
      custom_list_id: customListId,
    });
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Delete a movie
 */
export async function deleteMovie(imdbId: string): Promise<void> {
  try {
    await apiClient.delete(`/movies/${imdbId}`);
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}
