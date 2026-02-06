import { useState, useMemo } from "react";
import { Film, RefreshCw, Filter, Search, X } from "lucide-react";
import { MOVIE_STATUS } from "../../utils/constants";
import { sortMovies, filterMovies, getAllRecommenders, getDecades, getGenres } from "../../utils/helpers";
import MovieCard from "../MovieCard";
import FilterSheet from "./FilterSheet";

export default function MovieList({ status, movies, onMovieClick, onRefresh }) {
  const [sortBy, setSortBy] = useState(
    status === MOVIE_STATUS.WATCHED ? "dateWatched" : "dateRecommended",
  );
  const [filterRecommender, setFilterRecommender] = useState("");
  const [filterGenre, setFilterGenre] = useState("");
  const [filterDecade, setFilterDecade] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const statusMovies = useMemo(() => movies.filter((m) => m.status === status), [movies, status]);

  const filteredMovies = useMemo(
    () =>
      filterMovies(statusMovies, {
        recommender: filterRecommender,
        genre: filterGenre,
        decade: filterDecade,
        search: searchQuery,
      }),
    [statusMovies, filterRecommender, filterGenre, filterDecade, searchQuery],
  );

  const sortedMovies = useMemo(() => sortMovies(filteredMovies, sortBy), [filteredMovies, sortBy]);

  const recommenders = useMemo(() => getAllRecommenders(movies), [movies]);
  const genres = useMemo(() => getGenres(statusMovies), [statusMovies]);
  const decades = useMemo(() => getDecades(statusMovies), [statusMovies]);

  const activeFiltersCount = [filterRecommender, filterGenre, filterDecade].filter(Boolean).length;
  const hasSearchQuery = searchQuery.trim().length > 0;

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

      {/* Search */}
      <div className="relative">
        <Search className="w-4 h-4 text-ios-tertiary-label absolute left-3 top-1/2 -translate-y-1/2" />
        {hasSearchQuery && (
          <button
            type="button"
            onClick={() => setSearchQuery("")}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-ios-tertiary-label hover:text-ios-secondary-label"
            aria-label="Clear search"
          >
            <X className="w-4 h-4" />
          </button>
        )}
        <input
          type="text"
          className="ios-search pl-10 pr-9"
          placeholder="Search title, genre, cast, director..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          aria-label="Search movies"
          autoComplete="off"
        />
      </div>

      {/* Movie List */}
      {sortedMovies.length === 0 ? (
        <div className="ios-card text-center py-16">
          <Film className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
          <p className="text-ios-headline mb-1">No movies here</p>
          <p className="text-ios-secondary-label text-sm">
            {hasSearchQuery || activeFiltersCount > 0
              ? "Try adjusting your search or filters"
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
