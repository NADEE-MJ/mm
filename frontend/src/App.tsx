/**
 * Main App component - Website Layout
 * Standard web navigation with sidebar/top nav
 */

import { useCallback } from "react";
import { BrowserRouter, Routes, Route, useNavigate, useLocation, Link } from "react-router-dom";
import { RefreshCw, Clapperboard, Users, Folder, UserCog, Plus } from "lucide-react";

import { useAuth } from "./contexts/AuthContext";
import { ModalProvider } from "./contexts/ModalContext";
import { MoviesProvider, useMoviesContext } from "./contexts/MoviesContext";

import AuthScreen from "./components/AuthScreen";
import OfflineBanner from "./components/OfflineBanner";
import SyncIndicator from "./components/SyncIndicator";

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

function TopNav({ onAddClick }) {
  const location = useLocation();

  const navItems = [
    { path: "/", icon: Clapperboard, label: "Movies" },
    { path: "/people", icon: Users, label: "People" },
    { path: "/lists", icon: Folder, label: "Lists" },
    { path: "/account", icon: UserCog, label: "Account" },
  ];

  return (
    <nav className="site-nav">
      <div className="site-nav-inner">
        <div className="site-nav-brand">
          <Clapperboard className="w-6 h-6 text-app-yellow" />
          <span className="site-nav-title">Movie Manager</span>
        </div>

        <div className="site-nav-links">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive =
              item.path === "/"
                ? location.pathname === "/" || location.pathname.startsWith("/movie")
                : location.pathname.startsWith(item.path);

            return (
              <Link key={item.path} to={item.path} className={`site-nav-link ${isActive ? "active" : ""}`}>
                <Icon className="w-5 h-5" />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </div>

        <div className="site-nav-actions">
          <SyncIndicator iconOnly={true} />
          <button onClick={onAddClick} className="site-nav-add-btn" aria-label="Add movie">
            <Plus className="w-5 h-5" />
            <span className="hidden sm:inline">Add Movie</span>
          </button>
        </div>
      </div>
    </nav>
  );
}

function AppContent() {
  const { isAuthenticated, isLoading: authLoading, user, logout } = useAuth();
  const { movies, loading, loadMovies } = useMoviesContext();
  const navigate = useNavigate();

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
      <div className="site-loading">
        <RefreshCw className="w-8 h-8 animate-spin text-app-yellow" />
        <p className="text-secondary mt-3">Loading...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <AuthScreen />;
  }

  if (loading) {
    return (
      <div className="site-loading">
        <RefreshCw className="w-8 h-8 animate-spin text-app-yellow" />
        <p className="text-secondary mt-3">Loading movies...</p>
      </div>
    );
  }

  return (
    <div className="site-app">
      {/* Offline/Sync Banner */}
      <OfflineBanner />

      {/* Top Navigation */}
      <TopNav onAddClick={() => navigate("/add")} />

      {/* Main Content */}
      <main className="site-content">
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
          <Route path="/movie/:imdbId" element={<MovieDetailPage />} />
          <Route path="/add" element={<AddMoviePage />} />
          <Route
            path="/account"
            element={<AccountPage movies={movies} user={user} logout={logout} />}
          />
        </Routes>
      </main>
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
