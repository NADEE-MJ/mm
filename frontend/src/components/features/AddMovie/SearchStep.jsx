import { Search, Loader2 } from "lucide-react";
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
}) {
  return (
    <div className="space-y-4">
      {/* Search Form */}
      <form onSubmit={handleSearch}>
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ios-tertiary-label" />
          <input
            ref={searchInputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search movies..."
            className="ios-input pl-12 pr-20"
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
            {searchResults.map((movie) => (
              <button
                key={movie.id}
                onClick={() => handleSelectMovie(movie)}
                disabled={loading}
                className="ios-list-item py-3 w-full text-left disabled:opacity-50"
              >
                <div className="flex gap-3 flex-1">
                  <img
                    src={getPoster(movie.posterSmall)}
                    alt={movie.title}
                    className="w-12 h-18 object-cover rounded-lg flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <h3 className="text-ios-body font-semibold text-ios-label line-clamp-1">
                      {movie.title}
                    </h3>
                    <p className="text-ios-caption1 text-ios-secondary-label">
                      {movie.year}
                      {movie.rating && ` • ${movie.rating}`}
                    </p>
                    {movie.overview && (
                      <p className="text-ios-caption2 text-ios-tertiary-label line-clamp-2 mt-1">
                        {movie.overview}
                      </p>
                    )}
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Empty State */}
      {!loading && searchResults.length === 0 && !error && (
        <div className="text-center py-20">
          <Search className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
          <p className="text-ios-headline text-ios-label mb-1">Search for a movie</p>
          <p className="text-ios-caption1 text-ios-secondary-label">
            Enter a movie title to get started
          </p>
        </div>
      )}
    </div>
  );
}
