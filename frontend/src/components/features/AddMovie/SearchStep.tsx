import { Search, Loader2, CheckCircle } from "lucide-react";
import { getPoster } from "../../../utils/helpers";

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
}) {
  return (
    <div className="space-y-4">
      {/* Search Form */}
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
                        {movie.rating && ` • ${movie.rating}`}
                        {isInLibrary && " • Tap to view"}
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

      {/* Empty State */}
      {!loading && searchResults.length === 0 && !error && (
        <div className="text-center py-20">
          <Search className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
          <p className="text-ios-headline text-ios-label mb-1">Search for a movie or TV show</p>
          <p className="text-ios-caption1 text-ios-secondary-label">
            Enter a movie title to get started
          </p>
        </div>
      )}
    </div>
  );
}
