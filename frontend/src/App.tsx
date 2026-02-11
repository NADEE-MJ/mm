import { useCallback, useState } from "react";
import { BrowserRouter, Route, Routes, useSearchParams } from "react-router-dom";
import { RefreshCw } from "lucide-react";

import { useAuth } from "./contexts/AuthContext";
import { MoviesProvider, useMoviesContext } from "./contexts/MoviesContext";
import { useSync } from "./hooks/useSync";

import AuthScreen from "./components/AuthScreen";
import AppShell from "./components/layout/AppShell";
import MovieDetailPanel from "./components/MovieDetailPanel";
import Modal from "./components/ui/Modal";
import AddMovie from "./components/AddMovie";

import MoviesPage from "./pages/MoviesPage";
import PeoplePage from "./pages/PeoplePage";
import ListsPage from "./pages/ListsPage";
import AccountPage from "./pages/AccountPage";
import PersonDetailPage from "./pages/PersonDetailPage";

import { usePeople } from "./hooks/usePeople";

function LoadingScreen({ label = "Loading..." }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center">
      <RefreshCw className="w-8 h-8 animate-spin text-ios-blue" />
      <p className="text-ios-secondary-label mt-3">{label}</p>
    </div>
  );
}

function AddMovieModal({ onClose, onMovieAdded }) {
  const { addRecommendation } = useMoviesContext();
  const { people, getPeopleNames } = usePeople();

  const handleAdd = async (...args) => {
    await addRecommendation(...args);
  };

  const handleClose = (imdbId) => {
    if (imdbId) {
      onMovieAdded(imdbId);
    }
    onClose();
  };

  return (
    <Modal isOpen={true} onClose={() => handleClose(null)} title="Add Movie" maxWidth="860px">
      <AddMovie onAdd={handleAdd} onClose={handleClose} people={people} peopleNames={getPeopleNames()} />
    </Modal>
  );
}

function AppContent() {
  const { isAuthenticated, isLoading: authLoading, user, logout } = useAuth();
  const { movies, loading, loadMovies } = useMoviesContext();
  const [searchParams, setSearchParams] = useSearchParams();

  useSync();

  const [showAddMovie, setShowAddMovie] = useState(false);
  const selectedMovieId = searchParams.get("movie");

  const setSelectedMovieId = useCallback(
    (imdbId) => {
      const nextParams = new URLSearchParams(searchParams);
      if (imdbId) {
        nextParams.set("movie", imdbId);
      } else {
        nextParams.delete("movie");
      }
      setSearchParams(nextParams, { replace: true });
    },
    [searchParams, setSearchParams],
  );

  const handleRefresh = useCallback(async () => {
    await loadMovies();
  }, [loadMovies]);

  if (authLoading) {
    return <LoadingScreen />;
  }

  if (!isAuthenticated) {
    return <AuthScreen />;
  }

  if (loading) {
    return <LoadingScreen label="Loading movies..." />;
  }

  return (
    <AppShell panelOpen={Boolean(selectedMovieId)}>
      <Routes>
        <Route
          path="/"
          element={
            <MoviesPage
              movies={movies}
              onMovieClick={(movie) => setSelectedMovieId(movie.imdbId)}
              onRefresh={handleRefresh}
              onAddMovie={() => setShowAddMovie(true)}
            />
          }
        />
        <Route path="/people" element={<PeoplePage movies={movies} />} />
        <Route path="/people/:name" element={<PersonDetailPage movies={movies} />} />
        <Route
          path="/lists"
          element={<ListsPage movies={movies} onMovieClick={(movie) => setSelectedMovieId(movie.imdbId)} />}
        />
        <Route path="/account" element={<AccountPage movies={movies} user={user} logout={logout} />} />
      </Routes>

      {selectedMovieId && (
        <MovieDetailPanel imdbId={selectedMovieId} onClose={() => setSelectedMovieId(null)} />
      )}

      {showAddMovie && (
        <AddMovieModal
          onClose={() => setShowAddMovie(false)}
          onMovieAdded={(imdbId) => setSelectedMovieId(imdbId)}
        />
      )}
    </AppShell>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <MoviesProvider>
        <AppContent />
      </MoviesProvider>
    </BrowserRouter>
  );
}
