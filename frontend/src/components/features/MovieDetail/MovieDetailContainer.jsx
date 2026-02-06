/**
 * MovieDetail Container - iOS Style
 * Shows full movie details with actions
 */

import { useState } from "react";
import { ChevronRight } from "lucide-react";
import { VOTE_TYPE } from "../../../utils/constants";
import MovieHeader from "./MovieHeader";
import MovieInfo from "./MovieInfo";
import VotesSection from "./VotesSection";
import ActionsBar from "./ActionsBar";
import RatingModal from "./RatingModal";
import DownvoteModal from "./DownvoteModal";

export default function MovieDetailContainer({
  movie,
  onClose,
  onMarkWatched,
  onUpdateStatus,
  onAddVote,
  onRemoveVote,
  people = [],
  peopleNames = []
}) {
  const [showRating, setShowRating] = useState(false);
  const [showAddDownvote, setShowAddDownvote] = useState(false);

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

  const handleAddDownvote = async (person) => {
    try {
      await onAddVote(movie.imdbId, person, movie.tmdbData, movie.omdbData, VOTE_TYPE.DOWNVOTE);
    } catch (error) {
      console.error("Error adding downvote:", error);
    }
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
      <div className="bg-ios-bg min-h-screen">
        {/* Header with back button */}
        <header className="nav-stack-header">
          <button onClick={onClose} className="nav-stack-back-button">
            <ChevronRight className="w-5 h-5 rotate-180" />
            <span>Back</span>
          </button>
        </header>

        {/* Movie Content */}
        <div className="pb-32">
          <MovieHeader movie={movie} omdb={omdb} tmdb={tmdb} />
          <MovieInfo omdb={omdb} tmdb={tmdb} />
          <VotesSection
            allVotes={allVotes}
            watchHistory={watchHistory}
            onShowAddDownvote={() => setShowAddDownvote(true)}
            onRemoveVote={handleRemoveVote}
          />
        </div>

        {/* Bottom Actions */}
        <ActionsBar
          movie={movie}
          watchHistory={watchHistory}
          onShowRating={() => setShowRating(true)}
          onStatusChange={handleStatusChange}
        />
      </div>

      {/* Rating Modal */}
      <RatingModal
        isOpen={showRating}
        onClose={() => setShowRating(false)}
        onSave={handleMarkWatched}
        initialRating={watchHistory?.myRating || 7.0}
      />

      {/* Add Downvote Modal */}
      <DownvoteModal
        isOpen={showAddDownvote}
        onClose={() => setShowAddDownvote(false)}
        peopleNames={peopleNames}
        onAdd={handleAddDownvote}
      />
    </>
  );
}
