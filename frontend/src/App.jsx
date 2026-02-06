/**
 * Main App component - iOS Style
 * Simplified routing and layout
 */

import { useState, useEffect, useCallback } from "react";
import { BrowserRouter, Routes, Route, useNavigate } from "react-router-dom";
import { RefreshCw, LogOut } from "lucide-react";

import { useAuth } from "./contexts/AuthContext";
import { ModalProvider } from "./contexts/ModalContext";
import { useMovies } from "./hooks/useMovies";
import { startAutoSync, stopAutoSync, fullSync } from "./services/syncQueue";

import AuthScreen from "./components/AuthScreen";
import SyncIndicator from "./components/SyncIndicator";
import { IOSTabBar } from "./components/ui";

// Page components
import MoviesPage from "./pages/MoviesPage";
import PeoplePage from "./pages/PeoplePage";
import ListsPage from "./pages/ListsPage";
import DeletedListPage from "./pages/DeletedListPage";
import StatsPage from "./pages/StatsPage";
import MovieDetailPage from "./pages/MovieDetailPage";
import AddMoviePage from "./pages/AddMoviePage";

function AppContent() {
  const { isAuthenticated, isLoading: authLoading, user, logout } = useAuth();
  const { movies, loading, loadMovies } = useMovies();
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated) {
      startAutoSync();
      return () => {
        stopAutoSync();
      };
    }

    stopAutoSync();
    return undefined;
  }, [isAuthenticated]);

  const handleRefresh = useCallback(async () => {
    await fullSync();
    await loadMovies();
  }, [loadMovies]);

  const handleMovieClick = useCallback((movie) => {
    navigate(`/movie/${movie.imdbId}`);
  }, [navigate]);

  // Loading states
  if (authLoading) {
    return (
      <div className="ios-loading-screen">
        <RefreshCw className="w-8 h-8 animate-spin text-ios-blue" />
        <p className="text-ios-secondary-label mt-3">Loading...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <AuthScreen />;
  }

  if (loading) {
    return (
      <div className="ios-loading-screen">
        <RefreshCw className="w-8 h-8 animate-spin text-ios-blue" />
        <p className="text-ios-secondary-label mt-3">Loading movies...</p>
      </div>
    );
  }

  return (
    <div className="ios-app">
      {/* Header */}
      <header className="ios-nav-header safe-area-top">
        <div className="ios-nav-header-content">
          <div>
            <h1 className="text-ios-large-title">Movie Manager</h1>
            <p className="text-ios-caption1 text-ios-secondary-label">{user?.username}</p>
          </div>
          <div className="flex items-center gap-3">
            <SyncIndicator />
            <button onClick={logout} className="ios-icon-button" title="Sign out">
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="ios-main-content">
        <Routes>
          <Route
            path="/"
            element={
              <MoviesPage
                movies={movies}
                onMovieClick={handleMovieClick}
                onRefresh={handleRefresh}
              />
            }
          />
          <Route path="/people" element={<PeoplePage movies={movies} />} />
          <Route path="/lists" element={<ListsPage movies={movies} />} />
          <Route
            path="/lists/deleted"
            element={
              <DeletedListPage
                movies={movies}
                onMovieClick={handleMovieClick}
                onRefresh={handleRefresh}
              />
            }
          />
          <Route path="/stats" element={<StatsPage movies={movies} user={user} />} />
          <Route path="/movie/:imdbId" element={<MovieDetailPage />} />
          <Route path="/add" element={<AddMoviePage />} />
        </Routes>
      </main>

      {/* Bottom Tab Bar */}
      <IOSTabBar onAddClick={() => navigate("/add")} />
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <ModalProvider>
        <AppContent />
      </ModalProvider>
    </BrowserRouter>
  );
}
