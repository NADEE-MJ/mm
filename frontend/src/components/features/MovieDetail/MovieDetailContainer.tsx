/**
 * MovieDetail Container - iOS Style
 * Shows full movie details with actions
 */

import { ChevronRight } from "lucide-react";
import MovieHeader from "./MovieHeader";
import MovieInfo from "./MovieInfo";
import WatchProviders from "./WatchProviders";
import VotesSection from "./VotesSection";
import ActionsBar from "./ActionsBar";
import NotesSection from "./NotesSection";

export default function MovieDetailContainer({
  movie,
  onClose,
  onMarkWatched,
  onUpdateStatus,
  onUpdateNotes,
  onUpdatePoster,
  onRemoveVote,
  onShowAddUpvote,
  onShowAddDownvote,
  onOpenPerson,
  onOpenGenre,
  onOpenCompany,
}) {
  if (!movie) return null;

  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};
  const allVotes = movie.recommendations || [];
  const watchHistory = movie.watchHistory;

  const handleMarkWatched = async () => {
    await onMarkWatched(movie.imdbId);
  };

  const handleStatusChange = async (newStatus) => {
    await onUpdateStatus(movie.imdbId, newStatus);
  };

  const handleNotesSave = async (notes) => {
    await onUpdateNotes(movie.imdbId, notes);
  };

  const handlePosterChange = async (posterUrl) => {
    await onUpdatePoster(movie.imdbId, posterUrl);
  };

  const handleRemoveVote = async (person) => {
    try {
      await onRemoveVote(movie.imdbId, person);
    } catch (error) {
      console.error("Error removing vote:", error);
    }
  };

  return (
    <div className="bg-ios-bg min-h-full flex flex-col">
      <header className="sticky top-0 z-[1] border-b border-[var(--color-ios-separator)] bg-[rgba(0,0,0,0.75)] px-4 py-2.5 backdrop-blur-[8px]">
        <button
          onClick={onClose}
          className="inline-flex items-center gap-1 rounded-[10px] bg-white/10 px-2.5 py-1.5 text-[0.85rem] font-semibold text-[var(--color-ios-label)]"
        >
          <ChevronRight className="w-5 h-5 rotate-180" />
          <span>Close</span>
        </button>
      </header>

      <div className="pb-8">
        <MovieHeader movie={movie} omdb={omdb} tmdb={tmdb} onChangePoster={handlePosterChange} />
        <ActionsBar
          movie={movie}
          onMarkWatched={handleMarkWatched}
          onStatusChange={handleStatusChange}
        />
        <NotesSection notes={movie.notes} onSave={handleNotesSave} />
        <WatchProviders watchProviders={tmdb.watchProviders} />
        <MovieInfo
          omdb={omdb}
          tmdb={tmdb}
          onOpenPerson={onOpenPerson}
          onOpenGenre={onOpenGenre}
          onOpenCompany={onOpenCompany}
        />
        <VotesSection
          allVotes={allVotes}
          watchHistory={watchHistory}
          onShowAddUpvote={onShowAddUpvote}
          onShowAddDownvote={onShowAddDownvote}
          onRemoveVote={handleRemoveVote}
        />
      </div>
    </div>
  );
}
