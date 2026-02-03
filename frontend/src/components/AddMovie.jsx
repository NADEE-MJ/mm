/**
 * AddMovie component
 * Search and add movies with recommendations
 */

import { useState } from 'react';
import { Search, Plus, X } from 'lucide-react';
import { searchMovies as searchTMDB, getMovieDetails } from '../services/tmdbAPI';
import { getMovieByImdbId } from '../services/omdbAPI';
import { getPoster } from '../utils/helpers';

export default function AddMovie({ onAdd, peopleNames = [] }) {
  const [query, setQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [selectedMovie, setSelectedMovie] = useState(null);
  const [recommender, setRecommender] = useState('');
  const [showSuggestions, setShowSuggestions] = useState(false);

  const handleSearch = async (e) => {
    e.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const results = await searchTMDB(query);
      setSearchResults(results);
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
      // Get full details from TMDB
      const tmdbDetails = await getMovieDetails(movie.id);

      if (!tmdbDetails.imdbId) {
        setError('No IMDb ID found for this movie');
        return;
      }

      // Get OMDb details
      const omdbDetails = await getMovieByImdbId(tmdbDetails.imdbId);

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

  const handleAddRecommendation = async (e) => {
    e.preventDefault();
    if (!selectedMovie || !recommender.trim()) return;

    try {
      await onAdd(selectedMovie.imdbId, recommender, selectedMovie.tmdbData, selectedMovie.omdbData);

      // Reset
      setSelectedMovie(null);
      setRecommender('');
      setQuery('');
      setSearchResults([]);
    } catch (err) {
      setError(err.message);
    }
  };

  const filteredSuggestions = peopleNames.filter(name =>
    name.toLowerCase().includes(recommender.toLowerCase())
  );

  return (
    <div className="card">
      <h2 className="text-2xl font-bold mb-4">Add Movie</h2>

      {!selectedMovie ? (
        <>
          {/* Search Form */}
          <form onSubmit={handleSearch} className="mb-4">
            <div className="flex gap-2">
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search for a movie..."
                className="input flex-1"
              />
              <button
                type="submit"
                disabled={loading || !query.trim()}
                className="btn-primary flex items-center gap-2"
              >
                <Search className="w-4 h-4" />
                Search
              </button>
            </div>
          </form>

          {/* Error */}
          {error && (
            <div className="bg-red-900/20 border border-red-500 text-red-300 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}

          {/* Loading */}
          {loading && (
            <div className="text-center py-8">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            </div>
          )}

          {/* Search Results */}
          {searchResults.length > 0 && (
            <div className="space-y-2">
              {searchResults.map(movie => (
                <div
                  key={movie.id}
                  onClick={() => handleSelectMovie(movie)}
                  className="flex gap-3 p-3 bg-gray-700 rounded hover:bg-gray-600 cursor-pointer transition-colors"
                >
                  <img
                    src={getPoster(movie.posterSmall)}
                    alt={movie.title}
                    className="w-12 h-18 object-cover rounded"
                  />
                  <div>
                    <h3 className="font-bold">
                      {movie.title} {movie.year && `(${movie.year})`}
                    </h3>
                    <p className="text-sm text-gray-400 line-clamp-2">
                      {movie.overview}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      ) : (
        <>
          {/* Selected Movie */}
          <div className="mb-4 p-4 bg-gray-700 rounded">
            <div className="flex gap-4">
              <img
                src={getPoster(selectedMovie.omdbData.poster || selectedMovie.tmdbData.poster)}
                alt={selectedMovie.omdbData.title}
                className="w-24 h-36 object-cover rounded"
              />
              <div>
                <h3 className="text-xl font-bold">
                  {selectedMovie.omdbData.title} ({selectedMovie.omdbData.year})
                </h3>
                <p className="text-sm text-gray-400 mt-2">
                  {selectedMovie.omdbData.plot}
                </p>
              </div>
            </div>
          </div>

          {/* Recommendation Form */}
          <form onSubmit={handleAddRecommendation}>
            <div className="mb-4 relative">
              <label className="block text-sm font-medium mb-2">
                Recommended by
              </label>
              <input
                type="text"
                value={recommender}
                onChange={(e) => {
                  setRecommender(e.target.value);
                  setShowSuggestions(true);
                }}
                onFocus={() => setShowSuggestions(true)}
                placeholder="Enter name..."
                className="input"
                required
              />

              {/* Autocomplete Suggestions */}
              {showSuggestions && filteredSuggestions.length > 0 && recommender && (
                <div className="absolute z-10 w-full mt-1 bg-gray-700 border border-gray-600 rounded-lg shadow-lg max-h-40 overflow-y-auto">
                  {filteredSuggestions.map(name => (
                    <div
                      key={name}
                      onClick={() => {
                        setRecommender(name);
                        setShowSuggestions(false);
                      }}
                      className="px-3 py-2 hover:bg-gray-600 cursor-pointer"
                    >
                      {name}
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="flex gap-2">
              <button type="submit" className="btn-primary flex items-center gap-2">
                <Plus className="w-4 h-4" />
                Add Recommendation
              </button>
              <button
                type="button"
                onClick={() => setSelectedMovie(null)}
                className="btn-secondary flex items-center gap-2"
              >
                <X className="w-4 h-4" />
                Cancel
              </button>
            </div>
          </form>
        </>
      )}
    </div>
  );
}
