import { useMemo, useState } from "react";
import { Film, Filter, RefreshCw, Search, X } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";
import {
  filterMovies,
  getAllRecommenders,
  getDecades,
  getGenres,
  sortMovies,
} from "../utils/helpers";
import MoviePosterCard from "../components/MoviePosterCard";
import FilterSheet from "../components/ui/FilterSheet";

const SORT_LABELS = {
  dateRecommended: "Date Added",
  dateWatched: "Date Watched",
  myRating: "My Rating",
  imdbRating: "IMDb Rating",
  year: "Year",
  title: "Title",
};

export default function MoviesPage({ movies, onMovieClick, onRefresh }) {
  const [currentTab, setCurrentTab] = useState("toWatch");
  const [sortBy, setSortBy] = useState("dateRecommended");
  const [filterRecommender, setFilterRecommender] = useState("");
  const [filterGenre, setFilterGenre] = useState("");
  const [filterDecade, setFilterDecade] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const status = currentTab === "watched" ? MOVIE_STATUS.WATCHED : MOVIE_STATUS.TO_WATCH;

  const toWatchCount = useMemo(
    () => movies.filter((movie) => movie.status === MOVIE_STATUS.TO_WATCH).length,
    [movies],
  );
  const watchedCount = useMemo(
    () => movies.filter((movie) => movie.status === MOVIE_STATUS.WATCHED).length,
    [movies],
  );

  const statusMovies = useMemo(
    () => movies.filter((movie) => movie.status === status),
    [movies, status],
  );

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

  const hasSearchQuery = searchQuery.trim().length > 0;
  const activeFiltersCount = [filterRecommender, filterGenre, filterDecade].filter(Boolean).length;

  const sortOptions =
    status === MOVIE_STATUS.WATCHED
      ? ["dateWatched", "myRating", "imdbRating", "year", "title"]
      : ["dateRecommended", "imdbRating", "year", "title"];

  const handleTabChange = (nextTab) => {
    setCurrentTab(nextTab);
    setSortBy(nextTab === "watched" ? "dateWatched" : "dateRecommended");
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await onRefresh();
    } finally {
      setIsRefreshing(false);
    }
  };

  return (
    <div className="space-y-5">
      <div className="movie-status-tabs">
        <button
          type="button"
          className={`movie-status-tab ${currentTab === "toWatch" ? "active" : ""}`}
          onClick={() => handleTabChange("toWatch")}
        >
          <span>To Watch</span>
          <span className="movie-status-count">{toWatchCount}</span>
        </button>
        <button
          type="button"
          className={`movie-status-tab ${currentTab === "watched" ? "active" : ""}`}
          onClick={() => handleTabChange("watched")}
        >
          <span>Watched</span>
          <span className="movie-status-count">{watchedCount}</span>
        </button>
      </div>

      <div className="movie-toolbar">
        <div className="movie-search-wrap">
          <Search className="movie-search-icon" />
          <input
            type="text"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            placeholder="Search title, genre, cast, director..."
            className="movie-search-input"
            autoComplete="off"
          />
          {hasSearchQuery && (
            <button
              type="button"
              className="movie-clear-search"
              onClick={() => setSearchQuery("")}
              aria-label="Clear search"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        <div className="movie-toolbar-actions">
          <button
            type="button"
            className={`app-secondary-button ${activeFiltersCount > 0 ? "active" : ""}`}
            onClick={() => setShowFilters(true)}
          >
            <Filter className="w-4 h-4" />
            <span>Filter</span>
            {activeFiltersCount > 0 && <span className="app-mini-badge">{activeFiltersCount}</span>}
          </button>

          <select
            value={sortBy}
            onChange={(event) => setSortBy(event.target.value)}
            className="movie-sort-select"
            aria-label="Sort movies"
          >
            {sortOptions.map((option) => (
              <option key={option} value={option}>
                {SORT_LABELS[option]}
              </option>
            ))}
          </select>

          <button type="button" className="app-secondary-button" onClick={handleRefresh}>
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? "animate-spin" : ""}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {sortedMovies.length === 0 ? (
        <div className="movie-empty-state">
          <Film className="w-14 h-14" />
          <h3>No movies here</h3>
          <p>
            {hasSearchQuery || activeFiltersCount > 0
              ? "Try adjusting your search or filters."
              : status === MOVIE_STATUS.TO_WATCH
                ? "Add your first movie to get started."
                : "Movies will appear here once watched."}
          </p>
        </div>
      ) : (
        <div className="movie-poster-grid">
          {sortedMovies.map((movie) => (
            <MoviePosterCard key={movie.imdbId} movie={movie} onClick={() => onMovieClick(movie)} />
          ))}
        </div>
      )}

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
