/**
 * MoviesContext - server-backed movie state for web clients.
 */

import { createContext, useContext, useState, useEffect, useCallback } from "react";
import api from "../services/api";
import { useAuth } from "./AuthContext";

const MoviesContext = createContext();

function normalizeMovie(serverMovie) {
  return {
    imdbId: serverMovie.imdb_id,
    mediaType: serverMovie.media_type || serverMovie.tmdb_data?.mediaType || "movie",
    tmdbData: serverMovie.tmdb_data || null,
    omdbData: serverMovie.omdb_data || null,
    lastModified: (serverMovie.last_modified || 0) * 1000,
    status: serverMovie.status || "toWatch",
    recommendations: (serverMovie.recommendations || []).map((rec) => ({
      id: rec.id,
      person: rec.person,
      date_recommended: rec.date_recommended,
      vote_type: rec.vote_type || "upvote",
    })),
    watchHistory: serverMovie.watch_history
      ? {
          imdbId: serverMovie.watch_history.imdb_id,
          dateWatched: (serverMovie.watch_history.date_watched || 0) * 1000,
          myRating: serverMovie.watch_history.my_rating,
        }
      : null,
  };
}

function getErrorMessage(err, fallback) {
  return err?.message || fallback;
}

export function MoviesProvider({ children }) {
  const { isAuthenticated } = useAuth();
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadMovies = useCallback(async () => {
    if (!isAuthenticated) {
      setMovies([]);
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      const allMovies = await api.getAllMovies();
      setMovies((allMovies || []).map(normalizeMovie));
      setError(null);
    } catch (err) {
      console.error("Error loading movies:", err);
      setError(getErrorMessage(err, "Failed to load movies"));
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    loadMovies();
  }, [loadMovies]);

  useEffect(() => {
    const handleRealtimeEvent = () => {
      loadMovies();
    };
    const handleForceRefresh = () => {
      loadMovies();
    };

    window.addEventListener("mm-sync-event", handleRealtimeEvent);
    window.addEventListener("mm-force-refresh", handleForceRefresh);
    return () => {
      window.removeEventListener("mm-sync-event", handleRealtimeEvent);
      window.removeEventListener("mm-force-refresh", handleForceRefresh);
    };
  }, [loadMovies]);

  const refreshMovies = useCallback(async () => {
    await loadMovies();
  }, [loadMovies]);

  const updateMovie = useCallback(async () => {
    await refreshMovies();
  }, [refreshMovies]);

  const addRecommendation = useCallback(
    async (
      imdbId,
      person,
      tmdbData = null,
      omdbData = null,
      voteType = "upvote",
      mediaType = "movie",
    ) => {
      await api.addRecommendation(
        imdbId,
        person,
        Date.now() / 1000,
        voteType,
        tmdbData,
        omdbData,
        mediaType,
      );
      await refreshMovies();
    },
    [refreshMovies],
  );

  const removeRecommendation = useCallback(
    async (imdbId, person) => {
      await api.removeRecommendation(imdbId, person);
      await refreshMovies();
    },
    [refreshMovies],
  );

  const markWatched = useCallback(
    async (imdbId, rating) => {
      await api.markWatched(imdbId, Date.now(), rating);
      await refreshMovies();
    },
    [refreshMovies],
  );

  const updateStatus = useCallback(
    async (imdbId, status) => {
      await api.updateMovieStatus(imdbId, status);
      await refreshMovies();
    },
    [refreshMovies],
  );

  const getMoviesByStatus = useCallback(
    (status) => movies.filter((movie) => movie.status === status),
    [movies],
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
    throw new Error("useMoviesContext must be used within a MoviesProvider");
  }
  return context;
}
