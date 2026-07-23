/**
 * AddMovie Container - iOS Style
 * Search and add movies with recommendations
 */

import { useState, useRef, useEffect, useMemo } from "react";
import { ChevronLeft } from "lucide-react";
import {
  searchMovies as searchTMDB,
  getMovieDetails,
  getTVDetails,
  discoverByGenre,
  discoverByPerson,
  discoverByCompany,
  discoverList,
  getRecommendationsForYou,
} from "../../../services/tmdbAPI";
import { getMovieByImdbId } from "../../../services/omdbAPI";
import SearchStep from "./SearchStep";
import RecommenderStep from "./RecommenderStep";

const DEFAULT_PERSON_COLOR = "#0a84ff";

const CURATED_CATEGORIES = [
  { kind: "for_you", label: "For You" },
  { kind: "popular", label: "Popular" },
  { kind: "top_rated", label: "Top Rated" },
  { kind: "trending", label: "Trending" },
  { kind: "now_playing", label: "In Theaters" },
  { kind: "coming_soon", label: "Coming Soon" },
];

function normalizeErrorMessage(err, fallback = "An unexpected error occurred") {
  return err?.message || fallback;
}

function sortDiscoverResults(results, sortMode) {
  if (sortMode === "rating") {
    return [...results].sort((a, b) => (b.voteAverage || 0) - (a.voteAverage || 0));
  }
  if (sortMode === "year") {
    return [...results].sort((a, b) => (Number(b.year) || 0) - (Number(a.year) || 0));
  }
  return results;
}

export default function AddMovieContainer({
  onAdd,
  onClose,
  people = [],
  peopleNames = [],
  movies = [],
  initialDiscover = null,
}) {
  const [query, setQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [selectedMovie, setSelectedMovie] = useState(null);
  const [selectedRecommenders, setSelectedRecommenders] = useState([]);
  const [customRecommender, setCustomRecommender] = useState("");
  const [showRecommenderInput, setShowRecommenderInput] = useState(false);
  const [addingMovie, setAddingMovie] = useState(false);
  const [discoverContext, setDiscoverContext] = useState(null);
  const [discoverResults, setDiscoverResults] = useState([]);
  const [sortMode, setSortMode] = useState("popularity");
  const [curatedByCategory, setCuratedByCategory] = useState({});
  const [curatedLoading, setCuratedLoading] = useState(false);

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

  // Live search-as-you-type, like TMDB's own search bar. `handleSearch` (Enter / button)
  // stays available for an immediate, non-debounced lookup.
  useEffect(() => {
    if (discoverContext) return;
    const trimmedQuery = query.trim();
    if (!trimmedQuery) {
      setSearchResults([]);
      setError(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);
    const timer = setTimeout(async () => {
      try {
        const results = await searchTMDB(trimmedQuery);
        if (cancelled) return;
        setSearchResults(results);
        if (results.length === 0) {
          setError("No results found. Try a different search term.");
        }
      } catch (err) {
        if (!cancelled) setError(normalizeErrorMessage(err, "Search failed"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, 350);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [query, discoverContext]);

  const runDiscover = async ({ mode, query: discoverQuery, role, label }) => {
    setLoading(true);
    setError(null);
    setSortMode("popularity");
    try {
      let results;
      if (mode === "genre") {
        results = await discoverByGenre(discoverQuery);
      } else if (mode === "company") {
        results = await discoverByCompany(discoverQuery);
      } else {
        results = await discoverByPerson(discoverQuery, role || "actor");
      }

      // Actors are rarely credited as directors; fall back to a director search
      // if the requested role came up empty (covers e.g. actor-directors).
      if (mode === "person" && results.length === 0 && role !== "director") {
        results = await discoverByPerson(discoverQuery, "director");
      }

      setDiscoverResults(results);
      setDiscoverContext({ mode, query: discoverQuery, role, label });
      if (results.length === 0) {
        setError(`No movies found for ${label}.`);
      }
    } catch (err) {
      setError(normalizeErrorMessage(err, "Failed to load results"));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!initialDiscover) return;
    setQuery("");
    setSearchResults([]);
    runDiscover(initialDiscover);
  }, [initialDiscover]);

  // Load "browse" rails once, so there's something to look at before typing a search —
  // mirrors mobile's curated categories in the Discover tab.
  useEffect(() => {
    let cancelled = false;
    setCuratedLoading(true);
    Promise.all(
      CURATED_CATEGORIES.map((category) =>
        category.kind === "for_you" ? getRecommendationsForYou(20) : discoverList(category.kind),
      ),
    )
      .then((results) => {
        if (cancelled) return;
        const byCategory = {};
        CURATED_CATEGORIES.forEach((category, idx) => {
          byCategory[category.kind] = results[idx] || [];
        });
        setCuratedByCategory(byCategory);
      })
      .catch(() => {
        if (!cancelled) setCuratedByCategory({});
      })
      .finally(() => {
        if (!cancelled) setCuratedLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const exitDiscover = () => {
    setDiscoverContext(null);
    setDiscoverResults([]);
    setSortMode("popularity");
    setError(null);
  };

  const sortedDiscoverResults = useMemo(
    () => sortDiscoverResults(discoverResults, sortMode),
    [discoverResults, sortMode],
  );

  const visibleResults = discoverContext ? sortedDiscoverResults : searchResults;

  const handleSelectMovie = async (movie) => {
    if (movie.mediaType === "person") {
      await runDiscover({ mode: "person", query: movie.title, role: "actor", label: movie.title });
      return;
    }

    // If already in library, let the user add another recommender right here instead of
    // bouncing them out to the detail panel.
    const existingImdbId = existingTmdbIdToImdbId.get(movie.id);
    if (existingImdbId) {
      const existingMovie = movies.find((entry) => entry.imdbId === existingImdbId);
      if (existingMovie) {
        setSelectedMovie({
          imdbId: existingMovie.imdbId,
          mediaType: existingMovie.mediaType || "movie",
          tmdbData: existingMovie.tmdbData,
          omdbData: existingMovie.omdbData,
          isExisting: true,
          existingRecommenderNames: (existingMovie.recommendations || []).map((rec) => rec.person),
        });
      } else {
        onClose(existingImdbId);
      }
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

  // Merge per-field (not whole-object) so a missing OMDb poster/rating doesn't blank out
  // a perfectly good TMDB one — this is what made the add-flow preview show a different
  // (or missing) poster than the movie's actual detail page after saving.
  const movieData = {
    ...(selectedMovie?.tmdbData || {}),
    ...(selectedMovie?.omdbData || {}),
    poster: selectedMovie?.omdbData?.poster || selectedMovie?.tmdbData?.poster,
  };

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
            searchResults={visibleResults}
            handleSelectMovie={handleSelectMovie}
            searchInputRef={searchInputRef}
            existingTmdbIds={existingTmdbIds}
            discoverContext={discoverContext}
            sortMode={sortMode}
            setSortMode={setSortMode}
            onExitDiscover={exitDiscover}
            curatedCategories={CURATED_CATEGORIES}
            curatedByCategory={curatedByCategory}
            curatedLoading={curatedLoading}
          />
        ) : (
          <RecommenderStep
            movieData={movieData}
            mediaType={selectedMovie.mediaType}
            isExisting={selectedMovie.isExisting}
            existingRecommenderNames={selectedMovie.existingRecommenderNames}
            onViewDetails={() => onClose(selectedMovie.imdbId)}
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
