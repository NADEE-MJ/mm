import { useMemo, useState } from "react";
import { Film, Filter, Plus, RefreshCw, Search, X } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";
import {
  filterMovies,
  getAllRecommenders,
  getDecades,
  getGenres,
  sortMovies,
} from "../utils/helpers";
import { MOVIE_SORT_LABELS, MOVIE_TAB_CONFIG, getSortOptionsForStatus } from "../utils/movies";
import MoviePosterCard from "../components/MoviePosterCard";
import FilterSheet from "../components/ui/FilterSheet";

const POSTER_SIZE_LABELS = {
  small: "Small Posters",
  medium: "Medium Posters",
  large: "Large Posters",
};

export default function MoviesPage({ movies, onMovieClick, onRefresh, onAddMovie }) {
  const [currentTab, setCurrentTab] = useState("toWatch");
  const [sortBy, setSortBy] = useState(MOVIE_TAB_CONFIG.toWatch.defaultSort);
  const [posterSize, setPosterSize] = useState("medium");
  const [mediaTypeFilter, setMediaTypeFilter] = useState("all");
  const [filterRecommender, setFilterRecommender] = useState("");
  const [filterGenre, setFilterGenre] = useState("");
  const [filterDecade, setFilterDecade] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const { status } = MOVIE_TAB_CONFIG[currentTab] || MOVIE_TAB_CONFIG.toWatch;

  const counts = useMemo(
    () =>
      movies.reduce(
        (acc, movie) => {
          if (movie.status === MOVIE_STATUS.TO_WATCH) {
            acc.toWatch += 1;
          } else if (movie.status === MOVIE_STATUS.WATCHED) {
            acc.watched += 1;
          }
          return acc;
        },
        { toWatch: 0, watched: 0 },
      ),
    [movies],
  );

  const statusMovies = useMemo(
    () => movies.filter((movie) => movie.status === status),
    [movies, status],
  );

  const filteredMovies = useMemo(
    () =>
      filterMovies(statusMovies, {
        mediaType: mediaTypeFilter,
        recommender: filterRecommender,
        genre: filterGenre,
        decade: filterDecade,
        search: searchQuery,
      }),
    [statusMovies, mediaTypeFilter, filterRecommender, filterGenre, filterDecade, searchQuery],
  );

  const sortedMovies = useMemo(() => sortMovies(filteredMovies, sortBy), [filteredMovies, sortBy]);

  const recommenders = useMemo(() => getAllRecommenders(movies), [movies]);
  const genres = useMemo(() => getGenres(statusMovies), [statusMovies]);
  const decades = useMemo(() => getDecades(statusMovies), [statusMovies]);

  const hasSearchQuery = searchQuery.trim().length > 0;
  const activeFiltersCount = [mediaTypeFilter !== "all", filterRecommender, filterGenre, filterDecade]
    .filter(Boolean).length;

  const sortOptions = getSortOptionsForStatus(status);

  const handleTabChange = (nextTab) => {
    setCurrentTab(nextTab);
    setSortBy((MOVIE_TAB_CONFIG[nextTab] || MOVIE_TAB_CONFIG.toWatch).defaultSort);
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await onRefresh();
    } finally {
      setIsRefreshing(false);
    }
  };

  const posterMin =
    posterSize === "small" ? "145px" : posterSize === "large" ? "220px" : "170px";
  const posterGap = posterSize === "large" ? "1rem" : "0.85rem";

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-[1.4rem] font-bold text-[var(--color-ios-label)]">Library</h1>
      </div>

      <div className="inline-flex gap-1 rounded-[13px] border border-[var(--color-ios-separator)] bg-white/10 p-[0.28rem]">
        {Object.entries(MOVIE_TAB_CONFIG).map(([tabKey, tab]) => (
          <button
            key={tabKey}
            type="button"
            className={`inline-flex items-center gap-2 rounded-[10px] px-3 py-2 font-semibold ${
              currentTab === tabKey
                ? "bg-white/10 text-[var(--color-ios-label)]"
                : "text-[var(--color-ios-label-secondary)]"
            }`}
            onClick={() => handleTabChange(tabKey)}
          >
            <span>{tab.label}</span>
            <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-white/10 text-[0.7rem]">
              {counts[tabKey] || 0}
            </span>
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="relative min-w-[220px] flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-ios-label-tertiary)]" />
          <input
            type="text"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            placeholder="Search title, genre, cast, director..."
            className="w-full rounded-xl border border-[var(--color-ios-separator)] bg-white/5 px-9 py-2.5"
            autoComplete="off"
          />
          {hasSearchQuery && (
            <button
              type="button"
              className="absolute right-1.5 top-1/2 inline-flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-lg bg-transparent text-[var(--color-ios-label-tertiary)]"
              onClick={() => setSearchQuery("")}
              aria-label="Clear search"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        <div className="inline-flex flex-wrap items-center gap-2">
          {onAddMovie && (
            <button
              type="button"
              className="inline-flex items-center gap-1.5 rounded-xl bg-[var(--color-ios-yellow)] px-3.5 py-2.5 text-[0.88rem] font-bold text-[#111111]"
              onClick={onAddMovie}
            >
              <Plus className="w-4 h-4" />
              <span>Add Title</span>
            </button>
          )}

          <select
            value={posterSize}
            onChange={(event) => setPosterSize(event.target.value)}
            className="app-select rounded-xl border border-[var(--color-ios-separator)] bg-white/10 px-3 py-2.5 text-[var(--color-ios-label)] outline-none focus:border-[rgba(10,132,255,0.6)] focus:shadow-[0_0_0_3px_rgba(10,132,255,0.2)]"
            aria-label="Poster size"
          >
            {Object.entries(POSTER_SIZE_LABELS).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>

          <button
            type="button"
            className={`inline-flex items-center justify-center gap-1.5 rounded-xl bg-white/10 px-3.5 py-2.5 font-semibold text-[var(--color-ios-label)] ${
              activeFiltersCount > 0
                ? "text-[var(--color-ios-yellow-light)] outline outline-1 outline-[rgba(219,165,6,0.65)]"
                : ""
            }`}
            onClick={() => setShowFilters(true)}
          >
            <Filter className="w-4 h-4" />
            <span>Filter</span>
            {activeFiltersCount > 0 && (
              <span className="inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-[var(--color-ios-red)] px-1.5 text-[0.68rem] font-bold text-white">
                {activeFiltersCount}
              </span>
            )}
          </button>

          <select
            value={sortBy}
            onChange={(event) => setSortBy(event.target.value)}
            className="app-select rounded-xl border border-[var(--color-ios-separator)] bg-white/10 px-3 py-2.5 text-[var(--color-ios-label)] outline-none focus:border-[rgba(10,132,255,0.6)] focus:shadow-[0_0_0_3px_rgba(10,132,255,0.2)]"
            aria-label="Sort movies"
          >
            {sortOptions.map((option) => (
              <option key={option} value={option}>
                {MOVIE_SORT_LABELS[option]}
              </option>
            ))}
          </select>

          <button
            type="button"
            className="inline-flex items-center justify-center gap-1.5 rounded-xl bg-white/10 px-3.5 py-2.5 font-semibold text-[var(--color-ios-label)]"
            onClick={handleRefresh}
          >
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? "animate-spin" : ""}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {sortedMovies.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-[var(--color-ios-separator)] px-4 py-12 text-center text-[var(--color-ios-label-secondary)]">
          <Film className="w-14 h-14" />
          <h3 className="mt-3 text-[1.1rem] text-[var(--color-ios-label)]">No titles here</h3>
          <p className="text-[0.92rem]">
            {hasSearchQuery || activeFiltersCount > 0
              ? "Try adjusting your search or filters."
              : status === MOVIE_STATUS.TO_WATCH
                ? "Add your first title to get started."
                : "Titles will appear here once watched."}
          </p>
        </div>
      ) : (
        <div
          className="grid [grid-template-columns:repeat(auto-fill,minmax(min(100%,var(--movie-poster-min)),1fr))]"
          style={{ "--movie-poster-min": posterMin, gap: posterGap }}
        >
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
        mediaTypeFilter={mediaTypeFilter}
        setMediaTypeFilter={setMediaTypeFilter}
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
