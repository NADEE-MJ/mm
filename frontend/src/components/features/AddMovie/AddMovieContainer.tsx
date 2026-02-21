/**
 * AddMovie Container - iOS Style
 * Search and add movies with recommendations
 */

import { useState, useRef, useEffect, useMemo } from "react";
import { ChevronLeft } from "lucide-react";
import { searchMovies as searchTMDB, getMovieDetails, getTVDetails } from "../../../services/tmdbAPI";
import { getMovieByImdbId } from "../../../services/omdbAPI";
import SearchStep from "./SearchStep";
import RecommenderStep from "./RecommenderStep";

const DEFAULT_PERSON_COLOR = "#0a84ff";

function normalizeErrorMessage(err, fallback = "An unexpected error occurred") {
  return err?.message || fallback;
}

export default function AddMovieContainer({ onAdd, onClose, people = [], peopleNames = [], movies = [] }) {
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
        : peopleNames.map((name) => ({ name, color: DEFAULT_PERSON_COLOR, emoji: null, quick_key: null })),
    [people, peopleNames],
  );

  // Build a map of TMDB ID → IMDB ID for already-added movies.
  const existingTmdbIdToImdbId = useMemo(() => {
    const map = new Map();
    for (const movie of movies) {
      const tmdbId = movie.tmdbData?.tmdbId;
      if (tmdbId) map.set(tmdbId, movie.imdbId);
    }
    return map;
  }, [movies]);

  const existingTmdbIds = useMemo(() => new Set(existingTmdbIdToImdbId.keys()), [existingTmdbIdToImdbId]);

  // De-duplicate recommenders by name while preserving server data.
  const allRecommenders = useMemo(() => {
    const map = new Map();
    const register = (option) => {
      if (!option?.name) return;
      const key = option.name.toLowerCase();
      if (!map.has(key)) {
        map.set(key, option);
      }
    };

    userPeople.forEach((person) =>
      register({
        name: person.name,
        color: person.color || DEFAULT_PERSON_COLOR,
        emoji: person.emoji,
        isDefault: !!person.quick_key,
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
    const trimmedQuery = query.trim();
    if (!trimmedQuery) return;

    setLoading(true);
    setError(null);

    try {
      const results = await searchTMDB(trimmedQuery);
      setSearchResults(results);
      if (results.length === 0) {
        setError("No results found. Try a different search term.");
      }
    } catch (err) {
      setError(normalizeErrorMessage(err, "Search failed"));
    } finally {
      setLoading(false);
    }
  };

  const handleSelectMovie = async (movie) => {
    if (movie.mediaType === "person") {
      setError("Select a movie or TV show to add.");
      return;
    }

    // If already in library, navigate to its detail panel directly.
    const existingImdbId = existingTmdbIdToImdbId.get(movie.id);
    if (existingImdbId) {
      onClose(existingImdbId);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const loadDetails = movie.mediaType === "tv" ? getTVDetails : getMovieDetails;
      const tmdbDetails = await loadDetails(movie.id);

      if (!tmdbDetails.imdbId) {
        setError("No IMDb ID found for this title. Cannot add.");
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
        mediaType: movie.mediaType || tmdbDetails.mediaType || "movie",
        tmdbData: tmdbDetails,
        omdbData: omdbDetails,
      });
    } catch (err) {
      setError(normalizeErrorMessage(err, "Failed to load title details"));
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
    const trimmedName = customRecommender.trim();
    if (trimmedName && !selectedRecommenders.includes(trimmedName)) {
      setSelectedRecommenders((prev) => [...prev, trimmedName]);
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
      const recommendationAdds = selectedRecommenders.map((recommenderName) =>
        onAdd(
          selectedMovie.imdbId,
          recommenderName,
          selectedMovie.tmdbData,
          selectedMovie.omdbData,
          "upvote",
          selectedMovie.mediaType || "movie",
        ),
      );
      const results = await Promise.allSettled(recommendationAdds);
      const failedCount = results.filter((result) => result.status === "rejected").length;
      if (failedCount > 0) {
        const successCount = results.length - failedCount;
        setError(
          successCount > 0
            ? `Added ${successCount} recommender(s), but ${failedCount} failed. Please try again for the failed ones.`
            : "Failed to add recommenders. Please try again.",
        );
      } else {
        onClose(selectedMovie.imdbId);
      }
    } catch (err) {
      setError(normalizeErrorMessage(err));
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
            existingTmdbIds={existingTmdbIds}
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
            onAddTitle={handleAddRecommendation}
            addingMovie={addingMovie}
          />
        )}

        {/* Error Display (shown in recommender step) */}
        {selectedMovie && error && (
          <div className="ios-card p-4 bg-ios-red/10 border border-ios-red/20 text-ios-red text-sm mt-4">
            {error}
          </div>
        )}
      </div>

    </div>
  );
}
