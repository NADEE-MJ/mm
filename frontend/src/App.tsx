/**
 * Main App component - iOS Style
 * Simplified routing and layout
 */

import { useCallback } from "react";
import { BrowserRouter, Routes, Route, useNavigate, useLocation } from "react-router-dom";
import { RefreshCw } from "lucide-react";

import { useAuth } from "./contexts/AuthContext";
import { ModalProvider } from "./contexts/ModalContext";
import { MoviesProvider, useMoviesContext } from "./contexts/MoviesContext";

import AuthScreen from "./components/AuthScreen";
import { IOSTabBar } from "./components/ui";
import OfflineBanner from "./components/OfflineBanner";

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
  const { movies, loading, loadMovies } = useMoviesContext();
  const navigate = useNavigate();
  const location = useLocation();

  // Detect if we're on a stacked/modal page
  const isStackedPage =
    location.pathname.startsWith("/movie/") ||
    location.pathname === "/add" ||
    location.pathname.startsWith("/people/add") ||
    (location.pathname.startsWith("/people/") && location.pathname !== "/people") ||
    location.pathname === "/lists/deleted";

  const handleRefresh = useCallback(async () => {
    await loadMovies();
  }, [loadMovies]);

  const handleMovieClick = useCallback(
    (movie) => {
      navigate(`/movie/${movie.imdbId}`);
    },
    [navigate],
  );

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
      {/* Offline/Sync Banner */}
      <OfflineBanner />

      {/* Main Content - Base Pages */}
      <main className={`ios-main-content ${isStackedPage ? "has-overlay" : ""}`}>
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
            path="/account"
            element={<AccountPage movies={movies} user={user} logout={logout} />}
          />
        </Routes>
      </main>

      {/* Stacked/Modal Pages - Rendered on top */}
      <Routes>
        <Route path="/people/add" element={<AddPersonPage />} />
        <Route path="/people/:personName" element={<PersonDetailPage movies={movies} />} />
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
        <Route path="/movie/:imdbId" element={<MovieDetailPage />} />
        <Route path="/add" element={<AddMoviePage />} />
      </Routes>

      {/* Bottom Tab Bar */}
      <IOSTabBar onAddClick={() => navigate("/add")} />
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <ModalProvider>
        <MoviesProvider>
          <AppContent />
        </MoviesProvider>
      </ModalProvider>
    </BrowserRouter>
  );
}
