import { Search, Loader2, CheckCircle, X } from "lucide-react";
import { getPoster } from "../../../utils/helpers";

const SORT_OPTIONS = [
  { value: "popularity", label: "Popularity" },
  { value: "rating", label: "Rating" },
  { value: "year", label: "Release Date" },
];

export default function SearchStep({
  query,
  setQuery,
  handleSearch,
  loading,
  error,
  searchResults,
  handleSelectMovie,
  searchInputRef,
  existingTmdbIds = new Set(),
  discoverContext = null,
  sortMode = "popularity",
  setSortMode,
  onExitDiscover,
  curatedCategories = [],
  curatedByCategory = {},
  curatedLoading = false,
}) {
  const showBrowse = !discoverContext && !query.trim() && !loading && searchResults.length === 0;
  return (
    <div className="space-y-4">
      {/* Discover Banner */}
      {discoverContext && (
        <div className="ios-card flex items-center justify-between gap-3 p-3">
          <div className="min-w-0">
            <p className="text-ios-caption1 text-ios-secondary-label">
              {discoverContext.mode === "genre"
                ? "Genre"
                : discoverContext.mode === "company"
                  ? "Studio"
                  : discoverContext.role === "director"
                    ? "Director"
                    : "Actor"}
            </p>
            <p className="text-ios-body font-semibold text-ios-label truncate">{discoverContext.label}</p>
          </div>
          <button
            type="button"
            onClick={onExitDiscover}
            className="inline-flex shrink-0 items-center gap-1 rounded-full bg-white/10 px-3 py-1.5 text-[0.8rem] font-medium text-ios-label"
          >
            <X className="w-3.5 h-3.5" />
            New Search
          </button>
        </div>
      )}

      {/* Sort Controls */}
      {discoverContext && searchResults.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {SORT_OPTIONS.map((option) => (
            <button
              key={option.value}
              type="button"
              onClick={() => setSortMode?.(option.value)}
              className={`ios-pill ${sortMode === option.value ? "active" : ""}`}
            >
              {option.label}
            </button>
          ))}
        </div>
      )}

      {/* Search Form */}
      {!discoverContext && (
        <form onSubmit={handleSearch}>
          <div className="relative">
            <Search className="pointer-events-none absolute left-3.5 top-1/2 h-[1.1rem] w-[1.1rem] -translate-y-1/2 text-[var(--color-ios-label-tertiary)]" />
            <input
              ref={searchInputRef}
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search movies, TV shows..."
              className="ios-input !pl-[2.65rem] pr-[6.2rem]"
              autoComplete="off"
            />
            <button
              type="submit"
              disabled={loading || !query.trim()}
              className="absolute right-2 top-1/2 -translate-y-1/2 px-4 py-1.5 bg-ios-blue text-white rounded-lg text-sm font-medium disabled:opacity-50 transition-opacity"
            >
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : "Search"}
            </button>
          </div>
        </form>
      )}

      {/* Error */}
      {error && (
        <div className="ios-card p-4 bg-ios-red/10 border border-ios-red/20 text-ios-red text-sm">
          {error}
        </div>
      )}

      {/* Loading */}
      {loading && searchResults.length === 0 && (
        <div className="text-center py-16">
          <Loader2 className="w-8 h-8 animate-spin text-ios-blue mx-auto mb-3" />
          <p className="text-ios-secondary-label">Searching...</p>
        </div>
      )}

      {/* Search Results */}
      {searchResults.length > 0 && (
        <div className="space-y-2">
          <p className="text-ios-caption1 text-ios-secondary-label px-1">
            {searchResults.length} results
          </p>
          <div className="ios-list">
            {searchResults.map((movie) => {
              const isInLibrary = movie.mediaType !== "person" && existingTmdbIds.has(movie.id);
              return (
                <button
                  key={movie.id}
                  onClick={() => handleSelectMovie(movie)}
                  disabled={loading}
                  className={`ios-list-item py-3 w-full text-left disabled:opacity-50 ${
                    movie.mediaType === "person" ? "opacity-70 cursor-default" : ""
                  }`}
                >
                  <div className="flex gap-3 flex-1">
                    <img
                      src={getPoster(movie.posterSmall)}
                      alt={movie.title}
                      className="w-12 h-18 object-cover rounded-lg flex-shrink-0"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <h3 className="text-ios-body font-semibold text-ios-label line-clamp-1">
                          {movie.title}
                        </h3>
                        {movie.mediaType === "tv" && !isInLibrary && (
                          <span className="rounded-full bg-ios-blue/20 px-2 py-0.5 text-[0.65rem] font-semibold text-ios-blue">
                            TV
                          </span>
                        )}
                        {movie.mediaType === "person" && (
                          <span className="rounded-full bg-white/10 px-2 py-0.5 text-[0.65rem] font-semibold text-ios-secondary-label">
                            Person
                          </span>
                        )}
                        {isInLibrary && (
                          <span className="inline-flex items-center gap-1 rounded-full bg-green-500/20 px-2 py-0.5 text-[0.65rem] font-semibold text-green-400">
                            <CheckCircle className="w-3 h-3" />
                            In Library
                          </span>
                        )}
                      </div>
                      <p className="text-ios-caption1 text-ios-secondary-label">
                        {movie.year}
                        {movie.voteAverage > 0 && ` • ★ ${movie.voteAverage.toFixed(1)}`}
                        {isInLibrary && " • Tap to add a recommender"}
                      </p>
                      {movie.mediaType === "person" && movie.knownFor?.length > 0 && (
                        <p className="text-ios-caption2 text-ios-tertiary-label mt-1">
                          Known for: {movie.knownFor.slice(0, 3).join(", ")}
                        </p>
                      )}
                      {movie.overview && !isInLibrary && (
                        <p className="text-ios-caption2 text-ios-tertiary-label line-clamp-2 mt-1">
                          {movie.overview}
                        </p>
                      )}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Browse — curated rails shown before typing a search */}
      {showBrowse && (
        <div className="space-y-6">
          {curatedLoading && Object.keys(curatedByCategory).length === 0 && (
            <div className="text-center py-10">
              <Loader2 className="w-6 h-6 animate-spin text-ios-blue mx-auto" />
            </div>
          )}
          {curatedCategories.map((category) => {
            const movies = curatedByCategory[category.kind] || [];
            if (movies.length === 0) return null;
            return (
              <div key={category.kind}>
                <p className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wide mb-2 px-1">
                  {category.label}
                </p>
                <div className="flex gap-3 overflow-x-auto pb-1 -mx-1 px-1">
                  {movies.slice(0, 15).map((movie) => {
                    const isInLibrary = existingTmdbIds.has(movie.id);
                    return (
                      <button
                        key={movie.id}
                        onClick={() => handleSelectMovie(movie)}
                        disabled={loading}
                        className="flex-shrink-0 w-28 text-left disabled:opacity-50"
                      >
                        <div className="relative">
                          <img
                            src={getPoster(movie.posterSmall)}
                            alt={movie.title}
                            className="w-28 h-42 object-cover rounded-lg"
                          />
                          {isInLibrary && (
                            <span className="absolute top-1 right-1 rounded-full bg-green-500/90 p-1">
                              <CheckCircle className="w-3 h-3 text-white" />
                            </span>
                          )}
                        </div>
                        <p className="text-ios-caption2 text-ios-label font-medium line-clamp-2 mt-1">
                          {movie.title}
                        </p>
                        <p className="text-ios-caption2 text-ios-tertiary-label">{movie.year}</p>
                      </button>
                    );
                  })}
                </div>
              </div>
            );
          })}
          {!curatedLoading && Object.values(curatedByCategory).every((list) => !list?.length) && (
            <div className="text-center py-20">
              <Search className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
              <p className="text-ios-headline text-ios-label mb-1">Search for a movie or TV show</p>
              <p className="text-ios-caption1 text-ios-secondary-label">
                Enter a movie title to get started
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
