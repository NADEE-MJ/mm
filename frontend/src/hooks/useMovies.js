/**
 * useMovies hook
 * Manages movie data from IndexedDB with optimistic updates
 */

import { useState, useEffect } from 'react';
import { getAllMovies, saveMovie, addToSyncQueue, getPerson, savePerson } from '../services/storage';

export function useMovies() {
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Load movies from IndexedDB
  const loadMovies = async () => {
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
  };

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

  // Add a recommendation
  const addRecommendation = async (imdbId, person, tmdbData = null, omdbData = null) => {
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
      };

      movie.recommendations = movie.recommendations || [];
      movie.recommendations.push(recommendation);

      await saveMovie(movie);

      // Add to sync queue
      await addToSyncQueue('addRecommendation', {
        imdb_id: imdbId,
        person,
        date_recommended: recommendation.date_recommended,
        tmdb_data: tmdbData,
        omdb_data: omdbData,
      });

      await loadMovies();
    } catch (err) {
      console.error('Error adding recommendation:', err);
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
    markWatched,
    updateStatus,
    getMoviesByStatus,
  };
}
