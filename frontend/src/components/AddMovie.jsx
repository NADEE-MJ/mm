/**
 * AddMovie component - iOS Style
 * Search and add movies with recommendations
 */

import { useState, useRef, useEffect } from "react";
import { Search, Plus, X, ChevronRight, Loader2, Users, Check } from "lucide-react";
import { searchMovies as searchTMDB, getMovieDetails } from "../services/tmdbAPI";
import { getMovieByImdbId } from "../services/omdbAPI";
import { getPoster } from "../utils/helpers";
import { DEFAULT_RECOMMENDERS } from "../utils/constants";

export default function AddMovie({ onAdd, onClose, peopleNames = [] }) {
  const [query, setQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [selectedMovie, setSelectedMovie] = useState(null);
  const [selectedRecommenders, setSelectedRecommenders] = useState([]);
  const [customRecommender, setCustomRecommender] = useState("");
  const [showRecommenderInput, setShowRecommenderInput] = useState(false);
  const [addingMovie, setAddingMovie] = useState(false);

  const searchInputRef = useRef(null);
  const customInputRef = useRef(null);

  // Combine default recommenders with user's people
  const allRecommenders = [
    ...DEFAULT_RECOMMENDERS.map((r) => r.name),
    ...peopleNames.filter((name) => !DEFAULT_RECOMMENDERS.some((d) => d.name === name)),
  ];

  // Focus search input on mount
  useEffect(() => {
    if (!selectedMovie) {
      searchInputRef.current?.focus();
    }
  }, [selectedMovie]);

  useEffect(() => {
    if (showRecommenderInput) {
      customInputRef.current?.focus();
    }
  }, [showRecommenderInput]);

  const handleSearch = async (e) => {
    e?.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const results = await searchTMDB(query);
      setSearchResults(results);
      if (results.length === 0) {
        setError("No movies found. Try a different search term.");
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectMovie = async (movie) => {
    setLoading(true);
    setError(null);

    try {
      const tmdbDetails = await getMovieDetails(movie.id);

      if (!tmdbDetails.imdbId) {
        setError("No IMDb ID found for this movie. Cannot add.");
        setLoading(false);
        return;
      }

      let omdbDetails = null;
      try {
        omdbDetails = await getMovieByImdbId(tmdbDetails.imdbId);
      } catch (omdbErr) {
        console.warn("Could not fetch OMDb data:", omdbErr);
      }

      setSelectedMovie({
        imdbId: tmdbDetails.imdbId,
        tmdbData: tmdbDetails,
        omdbData: omdbDetails,
      });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const toggleRecommender = (name) => {
    setSelectedRecommenders((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name],
    );
  };

  const addCustomRecommender = () => {
    if (customRecommender.trim() && !selectedRecommenders.includes(customRecommender.trim())) {
      setSelectedRecommenders((prev) => [...prev, customRecommender.trim()]);
      setCustomRecommender("");
      setShowRecommenderInput(false);
    }
  };

  const handleAddRecommendation = async (e) => {
    e?.preventDefault();
    if (!selectedMovie || selectedRecommenders.length === 0) return;

    setAddingMovie(true);
    setError(null);
    try {
      // Add movie with all recommenders
      for (const recommender of selectedRecommenders) {
        await onAdd(
          selectedMovie.imdbId,
          recommender,
          selectedMovie.tmdbData,
          selectedMovie.omdbData,
        );
      }
      // Close modal after all recommenders are added successfully
      onClose();
    } catch (err) {
      setError(err.message);
      setAddingMovie(false);
    }
  };

  const movieData = selectedMovie?.omdbData || selectedMovie?.tmdbData || {};

  return (
    <div className="fixed inset-0 bg-ios-bg z-50 flex flex-col ios-fade-in">
      {/* Header */}
      <header className="ios-nav-header safe-area-top">
        <div className="ios-nav-header-content">
          <button
            onClick={selectedMovie ? () => setSelectedMovie(null) : onClose}
            className="flex items-center gap-1 text-ios-blue font-medium"
          >
            <ChevronRight className="w-5 h-5 rotate-180" />
            {selectedMovie ? "Back" : "Cancel"}
          </button>
          <h2 className="text-ios-headline font-semibold">
            {selectedMovie ? "Who Recommended?" : "Add Movie"}
          </h2>
          <div className="w-16" /> {/* Spacer for centering */}
        </div>
      </header>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        {!selectedMovie ? (
          <div className="p-4 space-y-4">
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
                            {movie.year && (
                              <span className="text-ios-secondary-label font-normal ml-1">
                                ({movie.year})
                              </span>
                            )}
                          </h3>
                          {movie.overview && (
                            <p className="text-ios-caption1 text-ios-secondary-label line-clamp-2 mt-1">
                              {movie.overview}
                            </p>
                          )}
                        </div>
                      </div>
                      <ChevronRight className="w-5 h-5 text-ios-tertiary-label flex-shrink-0" />
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
        ) : (
          <div className="p-4 space-y-6">
            {/* Selected Movie Preview */}
            <div className="ios-card p-4">
              <div className="flex gap-4">
                <img
                  src={getPoster(movieData.poster)}
                  alt={movieData.title}
                  className="w-20 h-30 object-cover rounded-xl flex-shrink-0"
                />
                <div className="flex-1 min-w-0">
                  <h3 className="text-ios-title3 font-bold text-ios-label">{movieData.title}</h3>
                  <p className="text-ios-caption1 text-ios-secondary-label">
                    {movieData.year}
                    {movieData.runtime && ` • ${movieData.runtime}`}
                  </p>
                  {movieData.genres && movieData.genres.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-2">
                      {movieData.genres.slice(0, 3).map((genre) => (
                        <span
                          key={genre}
                          className="text-ios-caption2 px-2 py-0.5 bg-ios-fill rounded-full text-ios-secondary-label"
                        >
                          {genre}
                        </span>
                      ))}
                    </div>
                  )}
                  <div className="flex gap-3 mt-2">
                    {movieData.imdbRating && (
                      <span className="text-ios-caption1 text-ios-yellow font-medium">
                        IMDb {movieData.imdbRating}
                      </span>
                    )}
                    {movieData.rtRating && (
                      <span className="text-ios-caption1 text-ios-red font-medium">
                        RT {movieData.rtRating}%
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Recommender Selection */}
            <div>
              <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
                Who Recommended This?
              </h3>
              <p className="text-ios-caption1 text-ios-tertiary-label mb-4">
                Select one or more recommenders. You can add multiple people.
              </p>

              {/* Selected Recommenders */}
              {selectedRecommenders.length > 0 && (
                <div className="flex flex-wrap gap-2 mb-4">
                  {selectedRecommenders.map((name) => (
                    <button
                      key={name}
                      onClick={() => toggleRecommender(name)}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-ios-blue text-white rounded-full text-sm font-medium transition-all active:scale-95"
                    >
                      {name}
                      <X className="w-4 h-4" />
                    </button>
                  ))}
                </div>
              )}

              {/* Recommender Options */}
              <div className="ios-list">
                {allRecommenders.map((name) => {
                  const isSelected = selectedRecommenders.includes(name);
                  const isDefault = DEFAULT_RECOMMENDERS.some((d) => d.name === name);
                  return (
                    <button
                      key={name}
                      onClick={() => toggleRecommender(name)}
                      className={`ios-list-item py-3 w-full text-left ${isSelected ? "bg-ios-blue/5" : ""}`}
                    >
                      <div className="flex items-center gap-3">
                        <div
                          className={`w-8 h-8 rounded-full flex items-center justify-center ${
                            isDefault ? "bg-ios-purple/20" : "bg-ios-fill"
                          }`}
                        >
                          <Users
                            className={`w-4 h-4 ${isDefault ? "text-ios-purple" : "text-ios-secondary-label"}`}
                          />
                        </div>
                        <span className="text-ios-label">{name}</span>
                        {isDefault && (
                          <span className="text-ios-caption2 text-ios-purple bg-ios-purple/10 px-2 py-0.5 rounded-full">
                            Quick
                          </span>
                        )}
                      </div>
                      {isSelected && <Check className="w-5 h-5 text-ios-blue" />}
                    </button>
                  );
                })}

                {/* Add Custom Recommender */}
                {!showRecommenderInput ? (
                  <button
                    onClick={() => setShowRecommenderInput(true)}
                    className="ios-list-item py-3 w-full text-left"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-ios-green/20 flex items-center justify-center">
                        <Plus className="w-4 h-4 text-ios-green" />
                      </div>
                      <span className="text-ios-blue">Add New Person</span>
                    </div>
                  </button>
                ) : (
                  <div className="p-4 bg-ios-secondary-fill border-t border-ios-separator">
                    <div className="flex gap-2">
                      <input
                        ref={customInputRef}
                        type="text"
                        value={customRecommender}
                        onChange={(e) => setCustomRecommender(e.target.value)}
                        onKeyDown={(e) => e.key === "Enter" && addCustomRecommender()}
                        placeholder="Enter name..."
                        className="ios-input flex-1"
                        autoComplete="off"
                      />
                      <button
                        onClick={addCustomRecommender}
                        disabled={!customRecommender.trim()}
                        className="btn-ios-primary px-4 disabled:opacity-50"
                      >
                        Add
                      </button>
                      <button
                        onClick={() => {
                          setShowRecommenderInput(false);
                          setCustomRecommender("");
                        }}
                        className="btn-ios-secondary px-4"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Error */}
            {error && (
              <div className="ios-card p-4 bg-ios-red/10 border border-ios-red/20 text-ios-red text-sm">
                {error}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Footer with action button */}
      {selectedMovie && (
        <div className="p-4 border-t border-ios-separator bg-ios-bg safe-area-bottom">
          <button
            onClick={handleAddRecommendation}
            disabled={selectedRecommenders.length === 0 || addingMovie}
            className="w-full btn-ios-primary py-3.5 disabled:opacity-50"
          >
            {addingMovie ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin mr-2" />
                Adding...
              </>
            ) : (
              <>
                <Plus className="w-5 h-5 mr-2" />
                Add Movie
                {selectedRecommenders.length > 0 && (
                  <span className="ml-1">
                    ({selectedRecommenders.length} recommender
                    {selectedRecommenders.length > 1 ? "s" : ""})
                  </span>
                )}
              </>
            )}
          </button>
        </div>
      )}
    </div>
  );
}
