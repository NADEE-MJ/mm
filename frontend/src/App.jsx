/**
 * Main App component
 * Handles routing, layout, and global state
 */

import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { Film, CheckCircle, AlertCircle, Users, Trash2, Plus } from 'lucide-react';

import { useMovies } from './hooks/useMovies';
import { usePeople } from './hooks/usePeople';
import { startAutoSync } from './services/syncQueue';
import { MOVIE_STATUS, RATING_THRESHOLD } from './utils/constants';
import { sortMovies, filterMovies, getAllRecommenders } from './utils/helpers';

import SyncIndicator from './components/SyncIndicator';
import MovieCard from './components/MovieCard';
import MovieDetail from './components/MovieDetail';
import AddMovie from './components/AddMovie';
import PeopleManager from './components/PeopleManager';
import RatingPrompt from './components/RatingPrompt';

function BottomNav() {
  const location = useLocation();

  const navItems = [
    { path: '/', icon: Film, label: 'To Watch' },
    { path: '/watched', icon: CheckCircle, label: 'Watched' },
    { path: '/questionable', icon: AlertCircle, label: 'Questionable' },
    { path: '/people', icon: Users, label: 'People' },
    { path: '/deleted', icon: Trash2, label: 'Deleted' },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-gray-900 border-t border-gray-700 z-40">
      <div className="flex justify-around max-w-screen-xl mx-auto">
        {navItems.map(item => {
          const Icon = item.icon;
          const isActive = location.pathname === item.path;

          return (
            <Link
              key={item.path}
              to={item.path}
              className={`flex flex-col items-center py-3 px-4 flex-1 transition-colors ${
                isActive
                  ? 'text-blue-500'
                  : 'text-gray-400 hover:text-gray-200'
              }`}
            >
              <Icon className="w-6 h-6" />
              <span className="text-xs mt-1">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

function MovieList({ status, movies, onMovieClick }) {
  const [sortBy, setSortBy] = useState('dateRecommended');
  const [filterRecommender, setFilterRecommender] = useState('');

  const filteredMovies = filterMovies(
    movies.filter(m => m.status === status),
    { recommender: filterRecommender }
  );

  const sortedMovies = sortMovies(filteredMovies, sortBy);
  const recommenders = getAllRecommenders(movies);

  return (
    <div className="space-y-4">
      {/* Filters and Sort */}
      <div className="flex gap-2 flex-wrap">
        <select
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value)}
          className="input flex-1 min-w-[150px]"
        >
          <option value="dateRecommended">Date Recommended</option>
          <option value="dateWatched">Date Watched</option>
          <option value="myRating">My Rating</option>
          <option value="imdbRating">IMDb Rating</option>
          <option value="year">Year</option>
          <option value="title">Title</option>
        </select>

        <select
          value={filterRecommender}
          onChange={(e) => setFilterRecommender(e.target.value)}
          className="input flex-1 min-w-[150px]"
        >
          <option value="">All Recommenders</option>
          {recommenders.map(name => (
            <option key={name} value={name}>{name}</option>
          ))}
        </select>
      </div>

      {/* Movie List */}
      {sortedMovies.length === 0 ? (
        <div className="card text-center text-gray-400 py-12">
          <Film className="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p className="text-lg">No movies here yet</p>
        </div>
      ) : (
        <div className="space-y-3">
          {sortedMovies.map(movie => (
            <MovieCard
              key={movie.imdbId}
              movie={movie}
              onClick={() => onMovieClick(movie)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function AppContent() {
  const { movies, loadMovies, addRecommendation, markWatched, updateStatus } = useMovies();
  const { people, getPeopleNames } = usePeople();
  const [selectedMovie, setSelectedMovie] = useState(null);
  const [showAddMovie, setShowAddMovie] = useState(false);
  const [ratingPrompt, setRatingPrompt] = useState(null);

  useEffect(() => {
    // Start auto-sync
    startAutoSync();
  }, []);

  const handleAddRecommendation = async (imdbId, person, tmdbData, omdbData) => {
    await addRecommendation(imdbId, person, tmdbData, omdbData);
    setShowAddMovie(false);
  };

  const handleMarkWatched = async (imdbId, rating) => {
    await markWatched(imdbId, rating);

    // Check if rating is below threshold
    if (rating < RATING_THRESHOLD) {
      const movie = movies.find(m => m.imdbId === imdbId);
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

    // Get all movies recommended by these people
    const recommenderNames = recommenders.map(r => r.person);
    const affectedMovies = movies.filter(m =>
      m.recommendations?.some(r => recommenderNames.includes(r.person)) &&
      m.status === MOVIE_STATUS.TO_WATCH
    );

    // Update status based on action
    if (action === 'questionable') {
      for (const affectedMovie of affectedMovies) {
        await updateStatus(affectedMovie.imdbId, MOVIE_STATUS.QUESTIONABLE);
      }
    } else if (action === 'delete') {
      for (const affectedMovie of affectedMovies) {
        await updateStatus(affectedMovie.imdbId, MOVIE_STATUS.DELETED);
      }
    }
    // 'keep' does nothing

    setRatingPrompt(null);
    loadMovies();
  };

  return (
    <div className="min-h-screen pb-20">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-gray-900 border-b border-gray-700 px-4 py-4">
        <div className="max-w-screen-xl mx-auto flex items-center justify-between gap-4">
          <h1 className="text-2xl font-bold">Movie Tracker</h1>
          <div className="flex items-center gap-3">
            <SyncIndicator />
            <button
              onClick={() => setShowAddMovie(true)}
              className="btn-primary flex items-center gap-2"
            >
              <Plus className="w-5 h-5" />
              <span className="hidden sm:inline">Add</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-screen-xl mx-auto px-4 py-6">
        <Routes>
          <Route
            path="/"
            element={
              <MovieList
                status={MOVIE_STATUS.TO_WATCH}
                movies={movies}
                onMovieClick={setSelectedMovie}
              />
            }
          />
          <Route
            path="/watched"
            element={
              <MovieList
                status={MOVIE_STATUS.WATCHED}
                movies={movies}
                onMovieClick={setSelectedMovie}
              />
            }
          />
          <Route
            path="/questionable"
            element={
              <MovieList
                status={MOVIE_STATUS.QUESTIONABLE}
                movies={movies}
                onMovieClick={setSelectedMovie}
              />
            }
          />
          <Route
            path="/deleted"
            element={
              <MovieList
                status={MOVIE_STATUS.DELETED}
                movies={movies}
                onMovieClick={setSelectedMovie}
              />
            }
          />
          <Route
            path="/people"
            element={<PeopleManager movies={movies} />}
          />
        </Routes>
      </main>

      {/* Bottom Navigation */}
      <BottomNav />

      {/* Modals */}
      {selectedMovie && (
        <MovieDetail
          movie={selectedMovie}
          onClose={() => setSelectedMovie(null)}
          onMarkWatched={handleMarkWatched}
          onUpdateStatus={updateStatus}
        />
      )}

      {showAddMovie && (
        <div className="fixed inset-0 bg-black bg-opacity-75 z-50 overflow-y-auto p-4">
          <div className="max-w-2xl mx-auto my-8">
            <AddMovie
              onAdd={handleAddRecommendation}
              peopleNames={getPeopleNames()}
            />
            <button
              onClick={() => setShowAddMovie(false)}
              className="mt-4 w-full btn-secondary"
            >
              Close
            </button>
          </div>
        </div>
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
