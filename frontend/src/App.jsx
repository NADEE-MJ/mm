/**
 * Main App component - iOS Style
 * Handles routing, layout, and global state
 */

import { useState, useEffect, useCallback, useMemo } from "react";
import { BrowserRouter, Routes, Route, Link, useLocation, useNavigate } from "react-router-dom";
import {
  Film,
  CheckCircle,
  Users,
  Trash2,
  Plus,
  Search,
  X,
  Filter,
  ChevronRight,
  RefreshCw,
  LogOut,
  List,
  MoreHorizontal,
  User,
  Folder,
} from "lucide-react";

import { useAuth } from "./contexts/AuthContext";
import { useMovies } from "./hooks/useMovies";
import { usePeople } from "./hooks/usePeople";
import { startAutoSync, fullSync } from "./services/syncQueue";
import { MOVIE_STATUS, RATING_THRESHOLD } from "./utils/constants";
import {
  sortMovies,
  filterMovies,
  getAllRecommenders,
  getDecades,
  getGenres,
} from "./utils/helpers";

import AuthScreen from "./components/AuthScreen";
import SyncIndicator from "./components/SyncIndicator";
import MovieCard from "./components/MovieCard";
import MovieDetail from "./components/MovieDetail";
import AddMovie from "./components/AddMovie";
import PeopleManager from "./components/PeopleManager";
import RatingPrompt from "./components/RatingPrompt";

function IOSTabBar() {
  const location = useLocation();

  const tabs = [
    { path: "/", icon: Film, label: "Movies" },
    { path: "/people", icon: Users, label: "People" },
    { path: "/lists", icon: Folder, label: "Lists" },
  ];

  return (
    <nav className="ios-tabbar safe-area-bottom">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        const isActive =
          tab.path === "/" ? location.pathname === "/" : location.pathname.startsWith(tab.path);

        return (
          <Link
            key={tab.path}
            to={tab.path}
            className={`ios-tabbar-item ${isActive ? "active" : ""}`}
          >
            <Icon className="ios-tabbar-icon" />
            <span className="ios-tabbar-label">{tab.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}

function IOSHeader({ title, subtitle, rightContent, onBack }) {
  return (
    <header className="ios-header safe-area-top">
      <div className="ios-header-content">
        {onBack && (
          <button onClick={onBack} className="ios-header-back">
            <ChevronRight className="w-5 h-5 rotate-180" />
            <span>Back</span>
          </button>
        )}
        <div className="ios-header-title-group">
          <h1 className="ios-header-title">{title}</h1>
          {subtitle && <p className="ios-header-subtitle">{subtitle}</p>}
        </div>
        {rightContent && <div className="ios-header-right">{rightContent}</div>}
      </div>
    </header>
  );
}

function IOSSheet({ isOpen, onClose, title, children }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50">
      <div className="ios-sheet-backdrop" onClick={onClose} />
      <div className="ios-sheet ios-slide-up">
        <div className="ios-sheet-handle" />
        <div className="ios-sheet-header">
          <h3 className="ios-sheet-title">{title}</h3>
          <button onClick={onClose} className="ios-sheet-close">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="ios-sheet-content">{children}</div>
      </div>
    </div>
  );
}

function IOSActionSheet({ isOpen, onClose, actions }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center">
      <div className="ios-sheet-backdrop" onClick={onClose} />
      <div className="ios-action-sheet ios-slide-up">
        <div className="ios-action-group">
          {actions.map((action, idx) => (
            <button
              key={idx}
              onClick={() => {
                action.onClick();
                onClose();
              }}
              className={`ios-action-item ${action.destructive ? "destructive" : ""}`}
            >
              {action.icon && <action.icon className="w-5 h-5" />}
              <span>{action.label}</span>
            </button>
          ))}
        </div>
        <button onClick={onClose} className="ios-action-cancel">
          Cancel
        </button>
      </div>
    </div>
  );
}

function FilterSheet({
  isOpen,
  onClose,
  sortBy,
  setSortBy,
  filterRecommender,
  setFilterRecommender,
  filterGenre,
  setFilterGenre,
  filterDecade,
  setFilterDecade,
  recommenders,
  genres,
  decades,
  status,
}) {
  const sortOptions =
    status === MOVIE_STATUS.WATCHED
      ? [
          { value: "dateWatched", label: "Date Watched" },
          { value: "myRating", label: "My Rating" },
          { value: "imdbRating", label: "IMDb Rating" },
          { value: "year", label: "Year" },
          { value: "title", label: "Title" },
        ]
      : [
          { value: "dateRecommended", label: "Date Added" },
          { value: "imdbRating", label: "IMDb Rating" },
          { value: "year", label: "Year" },
          { value: "title", label: "Title" },
        ];

  return (
    <IOSSheet isOpen={isOpen} onClose={onClose} title="Sort & Filter">
      <div className="space-y-6">
        {/* Sort */}
        <div>
          <label className="text-ios-label text-sm mb-3 block">Sort By</label>
          <div className="ios-list">
            {sortOptions.map((opt) => (
              <button
                key={opt.value}
                onClick={() => setSortBy(opt.value)}
                className={`ios-list-item ${sortBy === opt.value ? "active" : ""}`}
              >
                <span>{opt.label}</span>
                {sortBy === opt.value && <CheckCircle className="w-5 h-5 text-ios-blue" />}
              </button>
            ))}
          </div>
        </div>

        {/* Recommender Filter */}
        {recommenders.length > 0 && (
          <div>
            <label className="text-ios-label text-sm mb-3 block">Recommender</label>
            <select
              value={filterRecommender}
              onChange={(e) => setFilterRecommender(e.target.value)}
              className="ios-input"
            >
              <option value="">All Recommenders</option>
              {recommenders.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Genre Filter */}
        {genres.length > 0 && (
          <div>
            <label className="text-ios-label text-sm mb-3 block">Genre</label>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => setFilterGenre("")}
                className={`ios-pill ${!filterGenre ? "active" : ""}`}
              >
                All
              </button>
              {genres.slice(0, 12).map((genre) => (
                <button
                  key={genre}
                  onClick={() => setFilterGenre(genre)}
                  className={`ios-pill ${filterGenre === genre ? "active" : ""}`}
                >
                  {genre}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Decade Filter */}
        {decades.length > 0 && (
          <div>
            <label className="text-ios-label text-sm mb-3 block">Decade</label>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => setFilterDecade("")}
                className={`ios-pill ${!filterDecade ? "active" : ""}`}
              >
                All
              </button>
              {decades.map((decade) => (
                <button
                  key={decade}
                  onClick={() => setFilterDecade(decade)}
                  className={`ios-pill ${filterDecade === decade ? "active" : ""}`}
                >
                  {decade}s
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Clear Filters */}
        <button
          onClick={() => {
            setSortBy(status === MOVIE_STATUS.WATCHED ? "dateWatched" : "dateRecommended");
            setFilterRecommender("");
            setFilterGenre("");
            setFilterDecade("");
          }}
          className="btn-ios-secondary w-full"
        >
          Clear All Filters
        </button>
      </div>
    </IOSSheet>
  );
}

function MovieList({ status, movies, onMovieClick, onRefresh }) {
  const [sortBy, setSortBy] = useState(
    status === MOVIE_STATUS.WATCHED ? "dateWatched" : "dateRecommended",
  );
  const [filterRecommender, setFilterRecommender] = useState("");
  const [filterGenre, setFilterGenre] = useState("");
  const [filterDecade, setFilterDecade] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const statusMovies = useMemo(() => movies.filter((m) => m.status === status), [movies, status]);

  const filteredMovies = useMemo(
    () =>
      filterMovies(statusMovies, {
        recommender: filterRecommender,
        genre: filterGenre,
        decade: filterDecade,
      }),
    [statusMovies, filterRecommender, filterGenre, filterDecade],
  );

  const sortedMovies = useMemo(() => sortMovies(filteredMovies, sortBy), [filteredMovies, sortBy]);

  const recommenders = useMemo(() => getAllRecommenders(movies), [movies]);
  const genres = useMemo(() => getGenres(statusMovies), [statusMovies]);
  const decades = useMemo(() => getDecades(statusMovies), [statusMovies]);

  const activeFiltersCount = [filterRecommender, filterGenre, filterDecade].filter(Boolean).length;

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await onRefresh();
    } finally {
      setIsRefreshing(false);
    }
  };

  const statusLabels = {
    [MOVIE_STATUS.TO_WATCH]: "To Watch",
    [MOVIE_STATUS.WATCHED]: "Watched",
    [MOVIE_STATUS.DELETED]: "Deleted",
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h2 className="text-ios-title1">{statusLabels[status]}</h2>
          <span className="ios-badge">{sortedMovies.length}</span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="ios-icon-button"
            title="Refresh"
          >
            <RefreshCw className={`w-5 h-5 ${isRefreshing ? "animate-spin" : ""}`} />
          </button>
          <button
            onClick={() => setShowFilters(true)}
            className={`ios-icon-button ${activeFiltersCount > 0 ? "active" : ""}`}
          >
            <Filter className="w-5 h-5" />
            {activeFiltersCount > 0 && <span className="ios-badge-mini">{activeFiltersCount}</span>}
          </button>
        </div>
      </div>

      {/* Movie List */}
      {sortedMovies.length === 0 ? (
        <div className="ios-card text-center py-16">
          <Film className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
          <p className="text-ios-headline mb-1">No movies here</p>
          <p className="text-ios-secondary-label text-sm">
            {activeFiltersCount > 0
              ? "Try adjusting your filters"
              : status === MOVIE_STATUS.TO_WATCH
                ? "Add your first movie!"
                : "Movies will appear here"}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {sortedMovies.map((movie) => (
            <MovieCard key={movie.imdbId} movie={movie} onClick={() => onMovieClick(movie)} />
          ))}
        </div>
      )}

      {/* Filter Sheet */}
      <FilterSheet
        isOpen={showFilters}
        onClose={() => setShowFilters(false)}
        sortBy={sortBy}
        setSortBy={setSortBy}
        filterRecommender={filterRecommender}
        setFilterRecommender={setFilterRecommender}
        filterGenre={filterGenre}
        setFilterGenre={setFilterGenre}
        filterDecade={filterDecade}
        setFilterDecade={setFilterDecade}
        recommenders={recommenders}
        genres={genres}
        decades={decades}
        status={status}
      />
    </div>
  );
}

function MoviesTab({ movies, onMovieClick, onRefresh }) {
  const [currentTab, setCurrentTab] = useState("toWatch");

  return (
    <div>
      {/* Segmented Control */}
      <div className="ios-segmented-control mb-6">
        <button
          onClick={() => setCurrentTab("toWatch")}
          className={`ios-segment ${currentTab === "toWatch" ? "active" : ""}`}
        >
          To Watch
        </button>
        <button
          onClick={() => setCurrentTab("watched")}
          className={`ios-segment ${currentTab === "watched" ? "active" : ""}`}
        >
          Watched
        </button>
      </div>

      {currentTab === "toWatch" && (
        <MovieList
          status={MOVIE_STATUS.TO_WATCH}
          movies={movies}
          onMovieClick={onMovieClick}
          onRefresh={onRefresh}
        />
      )}
      {currentTab === "watched" && (
        <MovieList
          status={MOVIE_STATUS.WATCHED}
          movies={movies}
          onMovieClick={onMovieClick}
          onRefresh={onRefresh}
        />
      )}
    </div>
  );
}

function ListsTab({ movies, onMovieClick, onRefresh }) {
  const deletedMovies = useMemo(
    () => movies.filter((m) => m.status === MOVIE_STATUS.DELETED),
    [movies],
  );

  return (
    <div className="space-y-6">
      <h2 className="text-ios-title1">Lists</h2>

      {/* Built-in Lists */}
      <div className="ios-list">
        <Link to="/lists/deleted" className="ios-list-item">
          <div className="flex items-center gap-3">
            <div className="ios-list-icon bg-ios-red/20">
              <Trash2 className="w-5 h-5 text-ios-red" />
            </div>
            <span>Deleted</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-ios-secondary-label">{deletedMovies.length}</span>
            <ChevronRight className="w-5 h-5 text-ios-tertiary-label" />
          </div>
        </Link>
      </div>

      {/* Custom Lists Section */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-ios-headline">Custom Lists</h3>
          <button className="text-ios-blue text-sm font-medium">
            <Plus className="w-4 h-4 inline mr-1" />
            New List
          </button>
        </div>
        <div className="ios-card text-center py-8">
          <Folder className="w-12 h-12 mx-auto mb-3 text-ios-tertiary-label" />
          <p className="text-ios-secondary-label text-sm">
            Create custom lists to organize your movies
          </p>
        </div>
      </div>
    </div>
  );
}

function DeletedListView({ movies, onMovieClick, onRefresh }) {
  const navigate = useNavigate();

  return (
    <div>
      <button
        onClick={() => navigate("/lists")}
        className="flex items-center gap-1 text-ios-blue mb-4"
      >
        <ChevronRight className="w-5 h-5 rotate-180" />
        <span>Lists</span>
      </button>
      <MovieList
        status={MOVIE_STATUS.DELETED}
        movies={movies}
        onMovieClick={onMovieClick}
        onRefresh={onRefresh}
      />
    </div>
  );
}

function AppContent() {
  const { isAuthenticated, isLoading: authLoading, user, logout } = useAuth();
  const { movies, loading, loadMovies, addRecommendation, markWatched, updateStatus } = useMovies();
  const { people, getPeopleNames } = usePeople();
  const [selectedMovie, setSelectedMovie] = useState(null);
  const [showAddMovie, setShowAddMovie] = useState(false);
  const [ratingPrompt, setRatingPrompt] = useState(null);

  useEffect(() => {
    if (isAuthenticated) {
      startAutoSync();
    }
  }, [isAuthenticated]);

  const handleRefresh = useCallback(async () => {
    await fullSync();
    await loadMovies();
  }, [loadMovies]);

  const handleAddRecommendation = async (imdbId, person, tmdbData, omdbData) => {
    await addRecommendation(imdbId, person, tmdbData, omdbData);
    setShowAddMovie(false);
  };

  const handleMarkWatched = async (imdbId, rating) => {
    await markWatched(imdbId, rating);

    if (rating < RATING_THRESHOLD) {
      const movie = movies.find((m) => m.imdbId === imdbId);
      if (movie && movie.recommendations && movie.recommendations.length > 0) {
        setRatingPrompt({
          movie,
          recommenders: movie.recommendations,
        });
      }
    }

    setSelectedMovie(null);
    loadMovies();
  };

  const handleRatingPromptAction = async (action) => {
    if (!ratingPrompt) return;

    const { movie, recommenders } = ratingPrompt;
    const recommenderNames = recommenders.map((r) => r.person);
    const affectedMovies = movies.filter(
      (m) =>
        m.recommendations?.some((r) => recommenderNames.includes(r.person)) &&
        m.status === MOVIE_STATUS.TO_WATCH &&
        m.imdbId !== movie.imdbId,
    );

    if (action === "delete") {
      for (const affectedMovie of affectedMovies) {
        await updateStatus(affectedMovie.imdbId, MOVIE_STATUS.DELETED);
      }
    }

    setRatingPrompt(null);
    loadMovies();
  };

  const handleUpdateStatus = async (imdbId, status) => {
    await updateStatus(imdbId, status);
    setSelectedMovie(null);
    loadMovies();
  };

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
            <h1 className="text-ios-large-title">Movies</h1>
            <p className="text-ios-caption1 text-ios-secondary-label">{user?.username}</p>
          </div>
          <div className="flex items-center gap-3">
            <SyncIndicator />
            <button onClick={logout} className="ios-icon-button" title="Sign out">
              <LogOut className="w-5 h-5" />
            </button>
            <button onClick={() => setShowAddMovie(true)} className="btn-ios-primary">
              <Plus className="w-5 h-5" />
              <span className="hidden sm:inline ml-1">Add</span>
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
              <MoviesTab
                movies={movies}
                onMovieClick={setSelectedMovie}
                onRefresh={handleRefresh}
              />
            }
          />
          <Route path="/people" element={<PeopleManager movies={movies} />} />
          <Route
            path="/lists"
            element={
              <ListsTab movies={movies} onMovieClick={setSelectedMovie} onRefresh={handleRefresh} />
            }
          />
          <Route
            path="/lists/deleted"
            element={
              <DeletedListView
                movies={movies}
                onMovieClick={setSelectedMovie}
                onRefresh={handleRefresh}
              />
            }
          />
        </Routes>
      </main>

      {/* Bottom Tab Bar */}
      <IOSTabBar />

      {/* Modals */}
      {selectedMovie && (
        <MovieDetail
          movie={selectedMovie}
          onClose={() => setSelectedMovie(null)}
          onMarkWatched={handleMarkWatched}
          onUpdateStatus={handleUpdateStatus}
        />
      )}

      {showAddMovie && (
        <AddMovie
          onAdd={handleAddRecommendation}
          onClose={() => setShowAddMovie(false)}
          peopleNames={getPeopleNames()}
        />
      )}

      {ratingPrompt && (
        <RatingPrompt
          movie={ratingPrompt.movie}
          recommenders={ratingPrompt.recommenders}
          onAction={handleRatingPromptAction}
          onClose={() => setRatingPrompt(null)}
        />
      )}
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}
