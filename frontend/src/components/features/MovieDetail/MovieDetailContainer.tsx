/**
 * MovieDetail Container - iOS Style
 * Shows full movie details with actions
 */

import { useState } from "react";
import { ChevronRight } from "lucide-react";
import MovieHeader from "./MovieHeader";
import MovieInfo from "./MovieInfo";
import VotesSection from "./VotesSection";
import ActionsBar from "./ActionsBar";
import RatingModal from "./RatingModal";

export default function MovieDetailContainer({
  movie,
  onClose,
  onMarkWatched,
  onUpdateStatus,
  onRemoveVote,
  onShowAddUpvote,
  onShowAddDownvote,
}) {
  const [showRating, setShowRating] = useState(false);

  if (!movie) return null;

  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};
  const allVotes = movie.recommendations || [];
  const watchHistory = movie.watchHistory;

  const handleMarkWatched = async (rating) => {
    await onMarkWatched(movie.imdbId, rating);
    setShowRating(false);
  };

  const handleStatusChange = async (newStatus) => {
    await onUpdateStatus(movie.imdbId, newStatus);
  };

  const handleRemoveVote = async (person) => {
    try {
      await onRemoveVote(movie.imdbId, person);
    } catch (error) {
      console.error("Error removing vote:", error);
    }
  };

  return (
    <>
      <div className="bg-ios-bg min-h-full flex flex-col">
        <header className="app-panel-header">
          <button onClick={onClose} className="app-panel-back-button">
            <ChevronRight className="w-5 h-5 rotate-180" />
            <span>Close</span>
          </button>
        </header>

        <div className="pb-8">
          <MovieHeader movie={movie} omdb={omdb} tmdb={tmdb} />
          <MovieInfo omdb={omdb} tmdb={tmdb} />
          <VotesSection
            allVotes={allVotes}
            watchHistory={watchHistory}
            onShowAddUpvote={onShowAddUpvote}
            onShowAddDownvote={onShowAddDownvote}
            onRemoveVote={handleRemoveVote}
          />
        </div>

        <ActionsBar
          movie={movie}
          watchHistory={watchHistory}
          onShowRating={() => setShowRating(true)}
          onStatusChange={handleStatusChange}
        />
      </div>

      <RatingModal
        isOpen={showRating}
        onClose={() => setShowRating(false)}
        onSave={handleMarkWatched}
        initialRating={watchHistory?.myRating || 7.0}
      />
    </>
  );
}
