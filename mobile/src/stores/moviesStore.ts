import { create } from 'zustand';
import { MovieWithDetails, TMDBData, OMDBData } from '../types';
import * as movieStorage from '../services/storage/movies';
import * as enrichmentService from '../services/enrichment';
import { addToQueue } from '../services/sync/queue';

interface MoviesState {
  movies: MovieWithDetails[];
  isLoading: boolean;
  error: string | null;

  // Actions
  loadMovies: () => Promise<void>;
  getMovie: (imdbId: string) => Promise<MovieWithDetails | null>;
  addMovie: (
    imdbId: string | null,
    userId: string,
    tmdbData?: TMDBData,
    omdbData?: OMDBData,
    person?: string,
    voteType?: 'upvote' | 'downvote'
  ) => Promise<void>;
  deleteMovie: (imdbId: string) => Promise<void>;
  addRecommendation: (
    imdbId: string,
    userId: string,
    person: string,
    voteType?: 'upvote' | 'downvote'
  ) => Promise<void>;
  updateRecommendationVote: (
    imdbId: string,
    person: string,
    voteType: 'upvote' | 'downvote'
  ) => Promise<void>;
  removeRecommendation: (imdbId: string, person: string) => Promise<void>;
  markAsWatched: (imdbId: string, userId: string, rating: number) => Promise<void>;
  updateRating: (imdbId: string, rating: number) => Promise<void>;
  updateStatus: (
    imdbId: string,
    userId: string,
    status: 'toWatch' | 'watched' | 'deleted' | 'custom',
    customListId?: string
  ) => Promise<void>;
  getUnenrichedMovies: () => Promise<MovieWithDetails[]>;
  enrichMovie: (imdbId: string) => Promise<void>;
  bulkEnrich: () => Promise<void>;
  searchMovies: (query: string) => Promise<MovieWithDetails[]>;
  clearError: () => void;
}

export const useMoviesStore = create<MoviesState>((set, get) => ({
  movies: [],
  isLoading: false,
  error: null,

  loadMovies: async () => {
    set({ isLoading: true, error: null });

    try {
      const movies = await movieStorage.getAllMovies();
      set({ movies, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to load movies',
        isLoading: false,
      });
    }
  },

  getMovie: async (imdbId: string) => {
    try {
      return await movieStorage.getMovie(imdbId);
    } catch (error) {
      console.error('Failed to get movie:', error);
      return null;
    }
  },

  addMovie: async (
    imdbId: string | null,
    userId: string,
    tmdbData?: TMDBData,
    omdbData?: OMDBData,
    person?: string,
    voteType: 'upvote' | 'downvote' = 'upvote'
  ) => {
    try {
      const targetImdbId = imdbId || `temp_${Date.now()}`;

      // Optimistic update - save to SQLite immediately
      await movieStorage.saveMovie(targetImdbId, userId, tmdbData, omdbData);

      // If person provided, add recommendation
      if (person) {
        await movieStorage.addRecommendation(targetImdbId, userId, person, voteType);
      }

      // Reload movies to update UI
      await get().loadMovies();

      // Queue sync action
      await addToQueue('addRecommendation', {
        imdb_id: targetImdbId,
        tmdb_data: tmdbData,
        omdb_data: omdbData,
        person,
        vote_type: voteType,
      });

      // Trigger sync (will be implemented in sync processor)
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to add movie',
      });
      throw error;
    }
  },

  deleteMovie: async (imdbId: string) => {
    try {
      // Optimistic update
      await movieStorage.deleteMovie(imdbId);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('updateStatus', {
        imdb_id: imdbId,
        status: 'deleted',
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to delete movie',
      });
      throw error;
    }
  },

  addRecommendation: async (
    imdbId: string,
    userId: string,
    person: string,
    voteType: 'upvote' | 'downvote' = 'upvote'
  ) => {
    try {
      // Optimistic update
      await movieStorage.addRecommendation(imdbId, userId, person, voteType);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('addRecommendation', {
        imdb_id: imdbId,
        person,
        vote_type: voteType,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to add recommendation',
      });
      throw error;
    }
  },

  updateRecommendationVote: async (
    imdbId: string,
    person: string,
    voteType: 'upvote' | 'downvote'
  ) => {
    try {
      // Optimistic update
      await movieStorage.updateRecommendationVote(imdbId, person, voteType);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('updateRecommendationVote', {
        imdb_id: imdbId,
        person,
        vote_type: voteType,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to update vote',
      });
      throw error;
    }
  },

  removeRecommendation: async (imdbId: string, person: string) => {
    try {
      // Optimistic update
      await movieStorage.removeRecommendation(imdbId, person);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('removeRecommendation', {
        imdb_id: imdbId,
        person,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to remove recommendation',
      });
      throw error;
    }
  },

  markAsWatched: async (imdbId: string, userId: string, rating: number) => {
    try {
      // Optimistic update
      await movieStorage.markAsWatched(imdbId, userId, rating);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('markWatched', {
        imdb_id: imdbId,
        my_rating: rating,
        date_watched: Date.now() / 1000,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to mark as watched',
      });
      throw error;
    }
  },

  updateRating: async (imdbId: string, rating: number) => {
    try {
      // Optimistic update
      await movieStorage.updateRating(imdbId, rating);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('updateRating', {
        imdb_id: imdbId,
        rating,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to update rating',
      });
      throw error;
    }
  },

  updateStatus: async (
    imdbId: string,
    userId: string,
    status: 'toWatch' | 'watched' | 'deleted' | 'custom',
    customListId?: string
  ) => {
    try {
      // Optimistic update
      await movieStorage.setMovieStatus(imdbId, userId, status, customListId);

      // Reload movies
      await get().loadMovies();

      // Queue sync action
      await addToQueue('updateStatus', {
        imdb_id: imdbId,
        status,
        custom_list_id: customListId,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to update status',
      });
      throw error;
    }
  },

  searchMovies: async (query: string) => {
    try {
      return await movieStorage.searchMovies(query);
    } catch (error) {
      console.error('Failed to search movies:', error);
      return [];
    }
  },

  getUnenrichedMovies: async () => {
    try {
      return await movieStorage.getUnenrichedMovies();
    } catch (error) {
      console.error('Failed to get unenriched movies:', error);
      return [];
    }
  },

  enrichMovie: async (imdbId: string) => {
    try {
      const movie = await movieStorage.getMovie(imdbId);
      if (!movie) {
        throw new Error('Movie not found for enrichment');
      }
      await enrichmentService.enrichMovie(movie);
      await get().loadMovies();
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to enrich movie',
      });
      throw error;
    }
  },

  bulkEnrich: async () => {
    try {
      const movies = await movieStorage.getUnenrichedMovies();
      await enrichmentService.bulkEnrich(movies);
      await get().loadMovies();
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to bulk enrich movies',
      });
      throw error;
    }
  },

  clearError: () => set({ error: null }),
}));
