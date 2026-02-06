/**
 * useMovies hook
 * Manages movie data from IndexedDB with optimistic updates
 */

import { useState, useEffect, useCallback } from 'react';
import { getAllMovies, saveMovie, addToSyncQueue, getPerson, savePerson } from '../services/storage';

export function useMovies() {
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

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

  useEffect(() => {
    loadMovies();
  }, []);

  // Add or update a movie
  const updateMovie = async (movieData) => {
    try {
      await saveMovie(movieData);
      await loadMovies(); // Reload to get updated data
    } catch (err) {
      console.error('Error updating movie:', err);
      throw err;
    }
  };

  // Add a vote (recommendation)
  const addRecommendation = async (imdbId, person, tmdbData = null, omdbData = null, voteType = 'upvote') => {
    try {
      // Ensure person exists in people store
      const existingPerson = await getPerson(person);
      if (!existingPerson) {
        await savePerson({ name: person, is_trusted: false });
      }

      // Optimistic update
      const movie = movies.find(m => m.imdbId === imdbId) || {
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
      const existingIndex = movie.recommendations.findIndex(r => r.person === person);
      if (existingIndex >= 0) {
        // Update existing vote
        movie.recommendations[existingIndex] = recommendation;
      } else {
        // Add new vote
        movie.recommendations.push(recommendation);
      }

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

      await loadMovies();
    } catch (err) {
      console.error('Error adding vote:', err);
      throw err;
    }
  };

  // Remove a vote (recommendation)
  const removeRecommendation = async (imdbId, person) => {
    try {
      const movie = movies.find(m => m.imdbId === imdbId);
      if (!movie) throw new Error('Movie not found');

      // Optimistic update - remove the recommendation
      movie.recommendations = movie.recommendations.filter(r => r.person !== person);
      await saveMovie(movie);

      // Add to sync queue
      await addToSyncQueue('removeRecommendation', {
        imdb_id: imdbId,
        person,
      });

      await loadMovies();
    } catch (err) {
      console.error('Error removing recommendation:', err);
      throw err;
    }
  };

  // Mark movie as watched
  const markWatched = async (imdbId, rating) => {
    try {
      const movie = movies.find(m => m.imdbId === imdbId);
      if (!movie) throw new Error('Movie not found');

      const watchHistory = {
        imdbId,
        dateWatched: Date.now(),
        myRating: rating,
      };

      movie.watchHistory = watchHistory;
      movie.status = 'watched';

      await saveMovie(movie);

      // Add to sync queue
      await addToSyncQueue('markWatched', {
        imdb_id: imdbId,
        date_watched: watchHistory.dateWatched / 1000,
        my_rating: rating,
      });

      await loadMovies();
      return watchHistory;
    } catch (err) {
      console.error('Error marking watched:', err);
      throw err;
    }
  };

  // Update movie status
  const updateStatus = async (imdbId, status) => {
    try {
      const movie = movies.find(m => m.imdbId === imdbId);
      if (!movie) throw new Error('Movie not found');

      movie.status = status;
      await saveMovie(movie);

      // Add to sync queue
      await addToSyncQueue('updateStatus', {
        imdb_id: imdbId,
        status,
      });

      await loadMovies();
    } catch (err) {
      console.error('Error updating status:', err);
      throw err;
    }
  };

  // Filter movies by status
  const getMoviesByStatus = (status) => {
    return movies.filter(m => m.status === status);
  };

  return {
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
}
