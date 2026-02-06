/**
 * MoviesContext - Centralized movie state management
 * Provides a single source of truth for all movie data
 * Handles optimistic updates and offline-first functionality
 */

import { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import {
  getAllMovies,
  saveMovie,
  addToSyncQueue,
  getPerson,
  savePerson,
} from '../services/storage';
import { addSyncListener } from '../services/syncQueue';

const MoviesContext = createContext();

// Event emitter for movie changes
const movieChangeListeners = new Set();

export function emitMovieChange() {
  movieChangeListeners.forEach((callback) => callback());
}

function addMovieChangeListener(callback) {
  movieChangeListeners.add(callback);
  return () => movieChangeListeners.delete(callback);
}

export function MoviesProvider({ children }) {
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const lastSyncResultRef = useRef(null);

  // Load movies from IndexedDB
  const loadMovies = useCallback(async () => {
    try {
      setLoading(true);
      const allMovies = await getAllMovies();
      setMovies(allMovies);
      setError(null);
    } catch (err) {
      console.error('Error loading movies:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    loadMovies();
  }, [loadMovies]);

  // Listen for local movie changes
  useEffect(() => {
    const unsubscribe = addMovieChangeListener(() => {
      console.log('[MoviesContext] Local movie change detected, reloading...');
      loadMovies();
    });
    return unsubscribe;
  }, [loadMovies]);

  // Listen for sync completion and reload if changes occurred
  useEffect(() => {
    const unsubscribe = addSyncListener((status) => {
      // Only reload if sync just completed and we're now synced
      if (
        status.status === 'synced' &&
        !status.isProcessing &&
        !status.isSyncingFromServer &&
        lastSyncResultRef.current !== status.lastSync
      ) {
        // Update the ref to track this sync
        lastSyncResultRef.current = status.lastSync;

        // Only reload if it's not the initial mount (lastSync > 0)
        if (status.lastSync > 0) {
          console.log('[MoviesContext] Reloading movies after sync');
          loadMovies();
        }
      }
    });

    return unsubscribe;
  }, [loadMovies]);

  // Add or update a movie
  const updateMovie = useCallback(async (movieData) => {
    try {
      await saveMovie(movieData);
      emitMovieChange();
    } catch (err) {
      console.error('Error updating movie:', err);
      throw err;
    }
  }, []);

  // Add a recommendation (vote)
  const addRecommendation = useCallback(
    async (imdbId, person, tmdbData = null, omdbData = null, voteType = 'upvote') => {
      try {
        // Ensure person exists in people store
        const existingPerson = await getPerson(person);
        if (!existingPerson) {
          await savePerson({ name: person, is_trusted: false });
        }

        // Find existing movie or create new one
        const existingMovie = movies.find((m) => m.imdbId === imdbId);
        const movie = existingMovie || {
          imdbId,
          tmdbData,
          omdbData,
          status: 'toWatch',
          recommendations: [],
          watchHistory: null,
        };

        const recommendation = {
          person,
          date_recommended: Date.now() / 1000,
          vote_type: voteType,
        };

        movie.recommendations = movie.recommendations || [];

        // Check if this person already has a vote
        const existingIndex = movie.recommendations.findIndex((r) => r.person === person);
        if (existingIndex >= 0) {
          // Update existing vote
          movie.recommendations[existingIndex] = recommendation;
        } else {
          // Add new vote
          movie.recommendations.push(recommendation);
        }

        // Save to IndexedDB (optimistic update)
        await saveMovie(movie);

        // Add to sync queue
        await addToSyncQueue('addRecommendation', {
          imdb_id: imdbId,
          person,
          date_recommended: recommendation.date_recommended,
          vote_type: voteType,
          tmdb_data: tmdbData,
          omdb_data: omdbData,
        });

        // Notify all listeners
        emitMovieChange();
      } catch (err) {
        console.error('Error adding recommendation:', err);
        throw err;
      }
    },
    [movies]
  );

  // Remove a recommendation (vote)
  const removeRecommendation = useCallback(
    async (imdbId, person) => {
      try {
        const movie = movies.find((m) => m.imdbId === imdbId);
        if (!movie) throw new Error('Movie not found');

        // Optimistic update - remove the recommendation
        movie.recommendations = movie.recommendations.filter((r) => r.person !== person);
        await saveMovie(movie);

        // Add to sync queue
        await addToSyncQueue('removeRecommendation', {
          imdb_id: imdbId,
          person,
        });

        // Notify all listeners
        emitMovieChange();
      } catch (err) {
        console.error('Error removing recommendation:', err);
        throw err;
      }
    },
    [movies]
  );

  // Mark movie as watched
  const markWatched = useCallback(
    async (imdbId, rating) => {
      try {
        const movie = movies.find((m) => m.imdbId === imdbId);
        if (!movie) throw new Error('Movie not found');

        const watchHistory = {
          imdbId,
          dateWatched: Date.now(),
          myRating: rating,
        };

        movie.watchHistory = watchHistory;
        movie.status = 'watched';

        // Save to IndexedDB (optimistic update)
        await saveMovie(movie);

        // Add to sync queue
        await addToSyncQueue('markWatched', {
          imdb_id: imdbId,
          date_watched: watchHistory.dateWatched / 1000,
          my_rating: rating,
        });

        // Notify all listeners
        emitMovieChange();

        return watchHistory;
      } catch (err) {
        console.error('Error marking watched:', err);
        throw err;
      }
    },
    [movies]
  );

  // Update movie status
  const updateStatus = useCallback(
    async (imdbId, status) => {
      try {
        const movie = movies.find((m) => m.imdbId === imdbId);
        if (!movie) throw new Error('Movie not found');

        movie.status = status;

        // Save to IndexedDB (optimistic update)
        await saveMovie(movie);

        // Add to sync queue
        await addToSyncQueue('updateStatus', {
          imdb_id: imdbId,
          status,
        });

        // Notify all listeners
        emitMovieChange();
      } catch (err) {
        console.error('Error updating status:', err);
        throw err;
      }
    },
    [movies]
  );

  // Filter movies by status
  const getMoviesByStatus = useCallback(
    (status) => {
      return movies.filter((m) => m.status === status);
    },
    [movies]
  );

  const value = {
    movies,
    loading,
    error,
    loadMovies,
    updateMovie,
    addRecommendation,
    removeRecommendation,
    markWatched,
    updateStatus,
    getMoviesByStatus,
  };

  return <MoviesContext.Provider value={value}>{children}</MoviesContext.Provider>;
}

export function useMoviesContext() {
  const context = useContext(MoviesContext);
  if (!context) {
    throw new Error('useMoviesContext must be used within a MoviesProvider');
  }
  return context;
}
