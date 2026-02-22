/**
 * UnrankedQueuePanel — slide-in panel listing unranked watched movies.
 *
 * Flow:
 *  1. Click a movie → "Did you like it?" prompt appears
 *  2. Choose Liked / Didn't Like → opens RankingComparisonDialog for that group
 *  3. Binary comparisons → insertAtPosition called with position + liked flag
 */

import { useState } from "react";
import { X, Film, ThumbsUp, ThumbsDown } from "lucide-react";
import { getPoster } from "../../../utils/helpers";
import { useRankingContext } from "../../../contexts/RankingContext";
import RankingComparisonDialog from "./RankingComparisonDialog";

interface Props {
  isOpen: boolean;
  onClose: () => void;
}

export default function UnrankedQueuePanel({ isOpen, onClose }: Props) {
  const { unranked, ranked, insertAtPosition } = useRankingContext();

  // Step 1: movie selected, waiting for liked/disliked choice
  const [pendingCandidate, setPendingCandidate] = useState<any>(null);
  // Step 2: liked chosen, open comparison dialog
  const [activeComparison, setActiveComparison] = useState<{ candidate: any; liked: boolean } | null>(null);

  if (!isOpen) return null;

  const handleMovieClick = (movie: any) => {
    setPendingCandidate(movie);
  };

  const handleLikedChoice = (liked: boolean) => {
    if (!pendingCandidate) return;
    setActiveComparison({ candidate: pendingCandidate, liked });
    setPendingCandidate(null);
  };

  const handleCancelLiked = () => {
    setPendingCandidate(null);
  };

  const handleComparisonComplete = async (position: number) => {
    if (!activeComparison) return;
    const { candidate, liked } = activeComparison;
    setActiveComparison(null);
    try {
      await insertAtPosition(candidate.imdb_id, position, liked);
    } catch (err) {
      console.error("Failed to insert ranking:", err);
    }
  };

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Panel */}
      <div className="fixed right-0 top-0 z-40 flex h-full w-full max-w-sm flex-col border-l border-[var(--color-ios-separator)] bg-[rgba(18,18,18,0.97)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-ios-separator)] px-4 py-3">
          <h2 className="text-[1.05rem] font-bold text-[var(--color-ios-label)]">
            Rank Movies
            {unranked.length > 0 && (
              <span className="ml-2 inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-orange-500 px-1.5 text-[0.68rem] font-bold text-white">
                {unranked.length}
              </span>
            )}
          </h2>
          <button
            type="button"
            className="rounded-lg p-1.5 text-[var(--color-ios-label-secondary)] hover:bg-white/10"
            onClick={onClose}
            aria-label="Close panel"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto">
          {unranked.length === 0 ? (
            <div className="flex flex-col items-center justify-center gap-3 py-16 text-[var(--color-ios-label-secondary)]">
              <Film className="h-12 w-12 opacity-40" />
              <p className="text-sm">All caught up — every watched movie is ranked!</p>
            </div>
          ) : (
            <ul className="divide-y divide-[var(--color-ios-separator)]">
              {unranked.map((movie: any) => {
                const poster = getPoster(movie.poster_path);
                return (
                  <li key={movie.imdb_id}>
                    <button
                      type="button"
                      className="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-white/5"
                      onClick={() => handleMovieClick(movie)}
                    >
                      <div className="h-16 w-11 flex-shrink-0 overflow-hidden rounded-lg bg-[#1a1a1a]">
                        {poster ? (
                          <img src={poster} alt={movie.title} className="h-full w-full object-cover" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center">
                            <Film className="h-5 w-5 opacity-30" />
                          </div>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="truncate font-semibold text-[var(--color-ios-label)]">
                          {movie.title}
                        </p>
                        {movie.year && (
                          <p className="text-[0.78rem] text-[var(--color-ios-label-secondary)]">
                            {movie.year}
                          </p>
                        )}
                      </div>
                      <span className="text-[0.72rem] font-semibold text-orange-400">Rank →</span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>

      {/* Step 1: Liked / Didn't Like prompt */}
      {pendingCandidate && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm sm:items-center">
          <div className="w-full max-w-sm rounded-t-2xl border border-[var(--color-ios-separator)] bg-[rgba(22,22,22,0.98)] p-5 shadow-2xl sm:rounded-2xl">
            <div className="mb-4 flex items-center gap-3">
              {getPoster(pendingCandidate.poster_path) && (
                <img
                  src={getPoster(pendingCandidate.poster_path)}
                  alt={pendingCandidate.title}
                  className="h-14 w-10 rounded-lg object-cover flex-shrink-0"
                />
              )}
              <div className="min-w-0">
                <p className="text-[0.72rem] font-semibold uppercase tracking-wide text-[var(--color-ios-label-secondary)]">
                  Did you like this?
                </p>
                <p className="truncate font-bold text-[var(--color-ios-label)]">
                  {pendingCandidate.title}
                </p>
                {pendingCandidate.year && (
                  <p className="text-[0.75rem] text-[var(--color-ios-label-secondary)]">
                    {pendingCandidate.year}
                  </p>
                )}
              </div>
            </div>
            <div className="flex gap-3">
              <button
                type="button"
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-green-600 py-3 font-bold text-white hover:bg-green-500"
                onClick={() => handleLikedChoice(true)}
              >
                <ThumbsUp className="h-4 w-4" />
                Liked It
              </button>
              <button
                type="button"
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[rgba(255,255,255,0.08)] py-3 font-bold text-[var(--color-ios-label)] hover:bg-white/15"
                onClick={() => handleLikedChoice(false)}
              >
                <ThumbsDown className="h-4 w-4" />
                Didn't Like
              </button>
            </div>
            <button
              type="button"
              className="mt-3 w-full rounded-xl py-2.5 text-[0.85rem] text-[var(--color-ios-label-secondary)] hover:bg-white/5"
              onClick={handleCancelLiked}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Step 2: Binary comparison */}
      {activeComparison && (
        <RankingComparisonDialog
          isOpen={true}
          onClose={() => setActiveComparison(null)}
          candidate={activeComparison.candidate}
          ranked={ranked}
          liked={activeComparison.liked}
          onComplete={handleComparisonComplete}
        />
      )}
    </>
  );
}
