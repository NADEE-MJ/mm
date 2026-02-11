/**
 * AddMovie Container - iOS Style
 * Search and add movies with recommendations
 */

import { useState, useRef, useEffect, useMemo } from "react";
import { ChevronLeft, Loader2 } from "lucide-react";
import { searchMovies as searchTMDB, getMovieDetails } from "../../../services/tmdbAPI";
import { getMovieByImdbId } from "../../../services/omdbAPI";
import { DEFAULT_RECOMMENDERS } from "../../../utils/constants";
import SearchStep from "./SearchStep";
import RecommenderStep from "./RecommenderStep";

export default function AddMovieContainer({ onAdd, onClose, people = [], peopleNames = [] }) {
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

  const userPeople = useMemo(
    () =>
      people.length
        ? people
        : peopleNames.map((name) => ({ name, color: "#0a84ff", emoji: null, is_default: false })),
    [people, peopleNames],
  );

  // Combine default recommenders with user's people
  const allRecommenders = useMemo(() => {
    const map = new Map();
    const register = (option) => {
      if (!option?.name) return;
      const key = option.name.toLowerCase();
      if (!map.has(key)) {
        map.set(key, option);
      }
    };

    DEFAULT_RECOMMENDERS.forEach((rec) =>
      register({
        name: rec.name,
        color: rec.color || "#0a84ff",
        emoji: rec.emoji || "🎬",
        isDefault: true,
      }),
    );

    userPeople.forEach((person) =>
      register({
        name: person.name,
        color: person.color || "#0a84ff",
        emoji: person.emoji,
        isDefault: person.is_default ?? false,
      }),
    );

    return Array.from(map.values());
  }, [userPeople]);

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
      // Add movie with all recommenders concurrently
      const promises = selectedRecommenders.map((recommenderName) =>
        onAdd(
          selectedMovie.imdbId,
          recommenderName,
          selectedMovie.tmdbData,
          selectedMovie.omdbData,
        ).catch((err) => ({
          error: true,
          message: err.message,
        })),
      );

      const results = await Promise.all(promises);

      // Check if any failed
      const failedCount = results.filter((r) => r?.error).length;
      if (failedCount > 0) {
        const successCount = results.length - failedCount;
        if (successCount > 0) {
          setError(
            `Added ${successCount} recommender(s), but ${failedCount} failed. Please try again for the failed ones.`,
          );
        } else {
          setError(`Failed to add recommenders. Please try again.`);
        }
      } else {
        // All recommenders added successfully
        onClose(selectedMovie.imdbId);
      }
    } catch (err) {
      setError(`An unexpected error occurred: ${err.message}`);
    } finally {
      setAddingMovie(false);
    }
  };

  const movieData = selectedMovie?.omdbData || selectedMovie?.tmdbData || {};

  return (
    <div className="flex flex-col min-h-[62vh]">
      {selectedMovie && (
        <div className="mb-4">
          <button
            onClick={() => setSelectedMovie(null)}
            className="inline-flex items-center gap-1 rounded-[10px] bg-white/10 px-2.5 py-1.5 text-[0.85rem] font-semibold text-[var(--color-ios-label)]"
          >
            <ChevronLeft className="w-4 h-4" />
            <span>Back to Search</span>
          </button>
        </div>
      )}

      <div className="flex-1 overflow-y-auto">
        {!selectedMovie ? (
          <SearchStep
            query={query}
            setQuery={setQuery}
            handleSearch={handleSearch}
            loading={loading}
            error={error}
            searchResults={searchResults}
            handleSelectMovie={handleSelectMovie}
            searchInputRef={searchInputRef}
          />
        ) : (
          <RecommenderStep
            movieData={movieData}
            selectedRecommenders={selectedRecommenders}
            toggleRecommender={toggleRecommender}
            allRecommenders={allRecommenders}
            showRecommenderInput={showRecommenderInput}
            setShowRecommenderInput={setShowRecommenderInput}
            customRecommender={customRecommender}
            setCustomRecommender={setCustomRecommender}
            addCustomRecommender={addCustomRecommender}
            customInputRef={customInputRef}
          />
        )}

        {/* Error Display (shown in recommender step) */}
        {selectedMovie && error && (
          <div className="ios-card p-4 bg-ios-red/10 border border-ios-red/20 text-ios-red text-sm mt-4">
            {error}
          </div>
        )}
      </div>

      {selectedMovie && (
        <div className="border-t border-ios-separator pt-4 mt-4">
          <button
            onClick={handleAddRecommendation}
            disabled={selectedRecommenders.length === 0 || addingMovie}
            className="w-full btn-ios-primary py-3.5 disabled:opacity-50"
          >
            {addingMovie ? (
              <span className="flex items-center justify-center gap-2">
                <Loader2 className="w-5 h-5 animate-spin" />
                Adding...
              </span>
            ) : (
              `Add Movie with ${selectedRecommenders.length} Recommender${selectedRecommenders.length !== 1 ? "s" : ""}`
            )}
          </button>
        </div>
      )}
    </div>
  );
}
