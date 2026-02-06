/**
 * Main App component - iOS Style
 * Simplified routing and layout
 */

import { useEffect, useCallback, useRef } from "react";
import { BrowserRouter, Routes, Route, useNavigate } from "react-router-dom";
import { RefreshCw } from "lucide-react";

import { useAuth } from "./contexts/AuthContext";
import { ModalProvider } from "./contexts/ModalContext";
import { useMovies } from "./hooks/useMovies";
import { startAutoSync, stopAutoSync, fullSync, addSyncListener } from "./services/syncQueue";

import AuthScreen from "./components/AuthScreen";
import { IOSTabBar } from "./components/ui";

// Page components
import MoviesPage from "./pages/MoviesPage";
import PeoplePage from "./pages/PeoplePage";
import ListsPage from "./pages/ListsPage";
import DeletedListPage from "./pages/DeletedListPage";
import MovieDetailPage from "./pages/MovieDetailPage";
import AddMoviePage from "./pages/AddMoviePage";
import AccountPage from "./pages/AccountPage";
import AddPersonPage from "./pages/AddPersonPage";
import PersonDetailPage from "./pages/PersonDetailPage";

function AppContent() {
  const { isAuthenticated, isLoading: authLoading, user, logout } = useAuth();
  const { movies, loading, loadMovies } = useMovies();
  const navigate = useNavigate();
  const lastSyncResultRef = useRef(null);

  // Start auto-sync and listen for changes
  useEffect(() => {
    if (!isAuthenticated) {
      stopAutoSync();
      return undefined;
    }

    startAutoSync();

    // Listen for sync completion and reload only if changes occurred
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
          console.log('[App] Reloading movies after sync');
          loadMovies();
        }
      }
    });

    return () => {
      stopAutoSync();
      unsubscribe();
    };
  }, [isAuthenticated, loadMovies]);

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
          <Route path="/people/add" element={<AddPersonPage />} />
          <Route path="/people/:personName" element={<PersonDetailPage movies={movies} />} />
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
          <Route path="/account" element={<AccountPage movies={movies} user={user} logout={logout} />} />
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
