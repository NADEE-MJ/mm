import { useEffect, useMemo, useState } from "react";
import { useMoviesContext } from "../contexts/MoviesContext";
import { usePeople } from "../hooks/usePeople";
import { MOVIE_STATUS, RATING_THRESHOLD, VOTE_TYPE } from "../utils/constants";
import MovieDetail from "./MovieDetail";
import RatingPrompt from "./RatingPrompt";
import UpvoteModal from "./features/MovieDetail/UpvoteModal";
import DownvoteModal from "./features/MovieDetail/DownvoteModal";

export default function MovieDetailPanel({ imdbId, onClose }) {
  const { movies, markWatched, updateStatus, addRecommendation, removeRecommendation } =
    useMoviesContext();
  const { getPeopleNames } = usePeople();

  const [ratingPrompt, setRatingPrompt] = useState(null);
  const [showAddUpvote, setShowAddUpvote] = useState(false);
  const [showAddDownvote, setShowAddDownvote] = useState(false);

  const movie = useMemo(() => movies.find((entry) => entry.imdbId === imdbId), [movies, imdbId]);

  useEffect(() => {
    const handleEscape = (event) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleEscape);
    return () => window.removeEventListener("keydown", handleEscape);
  }, [onClose]);

  const handleMarkWatched = async (movieImdbId, rating) => {
    await markWatched(movieImdbId, rating);

    if (rating < RATING_THRESHOLD) {
      const currentMovie = movies.find((entry) => entry.imdbId === movieImdbId);
      if (currentMovie && currentMovie.recommendations && currentMovie.recommendations.length > 0) {
        setRatingPrompt({
          movie: currentMovie,
          recommenders: currentMovie.recommendations,
        });
      }
    }
  };

  const handleRatingPromptAction = async (action) => {
    if (!ratingPrompt) {
      return;
    }

    const { movie: promptMovie, recommenders } = ratingPrompt;
    const recommenderNames = recommenders.map((recommendation) => recommendation.person);
    const affectedMovies = movies.filter(
      (entry) =>
        entry.recommendations?.some((recommendation) => recommenderNames.includes(recommendation.person)) &&
        entry.status === MOVIE_STATUS.TO_WATCH &&
        entry.imdbId !== promptMovie.imdbId,
    );

    if (action === "delete") {
      for (const affectedMovie of affectedMovies) {
        await updateStatus(affectedMovie.imdbId, MOVIE_STATUS.DELETED);
      }
    }

    setRatingPrompt(null);
  };

  const handleAddVote = async (person, voteType, closeModal) => {
    if (!movie) {
      return;
    }
    await addRecommendation(
      movie.imdbId,
      person,
      movie.tmdbData,
      movie.omdbData,
      voteType,
      movie.mediaType || "movie",
    );
    closeModal(false);
  };

  const handleAddUpvote = async (person) => {
    await handleAddVote(person, VOTE_TYPE.UPVOTE, setShowAddUpvote);
  };

  const handleAddDownvote = async (person) => {
    await handleAddVote(person, VOTE_TYPE.DOWNVOTE, setShowAddDownvote);
  };

  if (!imdbId) {
    return null;
  }

  return (
    <>
      <div className="pointer-events-none fixed inset-0 z-[45]">
        <section className="pointer-events-auto fixed right-0 top-0 h-screen w-[min(500px,100vw)] overflow-y-auto border-l border-[var(--color-ios-separator)] bg-[#0b0b0b] animate-[panel-slide-in_0.2s_ease-out] max-md:w-screen min-[1600px]:w-[min(540px,100vw)]">
          {!movie ? (
            <div className="px-4 py-12 text-center text-[var(--color-ios-label-secondary)]">Movie not found.</div>
          ) : (
            <MovieDetail
              movie={movie}
              onClose={onClose}
              onMarkWatched={handleMarkWatched}
              onUpdateStatus={updateStatus}
              onRemoveVote={removeRecommendation}
              onShowAddUpvote={() => setShowAddUpvote(true)}
              onShowAddDownvote={() => setShowAddDownvote(true)}
            />
          )}
        </section>
      </div>

      {ratingPrompt && (
        <RatingPrompt
          movie={ratingPrompt.movie}
          recommenders={ratingPrompt.recommenders}
          onAction={handleRatingPromptAction}
          onClose={() => setRatingPrompt(null)}
        />
      )}

      <UpvoteModal
        isOpen={showAddUpvote}
        onClose={() => setShowAddUpvote(false)}
        peopleNames={getPeopleNames()}
        onAdd={handleAddUpvote}
      />

      <DownvoteModal
        isOpen={showAddDownvote}
        onClose={() => setShowAddDownvote(false)}
        peopleNames={getPeopleNames()}
        onAdd={handleAddDownvote}
      />
    </>
  );
}
