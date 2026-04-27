/**
 * RankingComparisonDialog — full-overlay binary search comparison UI.
 *
 * Shows the candidate movie vs the current mid-point of the same liked/disliked group.
 * YES/NO buttons drive the session forward until complete, then calls onComplete with
 * the final insertion position (1-indexed within the liked/disliked group).
 */

import { useEffect } from "react";
import { X, ThumbsUp, ThumbsDown, Trophy } from "lucide-react";
import { useRankingSession } from "../../../hooks/useRankingSession";
import { getPoster } from "../../../utils/helpers";

interface Props {
  isOpen: boolean;
  onClose: () => void;
  candidate: any;
  ranked: any[];
  liked: boolean;
  onComplete: (position: number) => void;
  excludeImdbId?: string;
}

export default function RankingComparisonDialog({
  isOpen,
  onClose,
  candidate,
  ranked,
  liked,
  onComplete,
  excludeImdbId,
}: Props) {
  const session = useRankingSession(ranked, candidate, liked, excludeImdbId);

  // If the same-group list is empty, session is immediately complete
  useEffect(() => {
    if (isOpen && session.isComplete) {
      onComplete(session.insertionPosition);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen, session.isComplete]);

  if (!isOpen) return null;

  const progressPct =
    session.maxSteps > 0 ? (session.stepNumber - 1) / session.maxSteps : 0;

  const groupLabel = liked ? "liked" : "disliked";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="relative flex w-full max-w-lg flex-col rounded-2xl border border-[var(--color-ios-separator)] bg-[rgba(22,22,22,0.98)] p-6 shadow-2xl">
        {/* Close */}
        <button
          type="button"
          className="absolute right-4 top-4 rounded-lg p-1.5 text-[var(--color-ios-label-secondary)] hover:bg-white/10"
          onClick={onClose}
          aria-label="Cancel ranking"
        >
          <X className="h-5 w-5" />
        </button>

        <h2 className="mb-1 text-center text-[1.1rem] font-bold text-[var(--color-ios-label)]">
          Rank Movie
        </h2>
        <p className="mb-3 text-center text-[0.72rem] font-semibold uppercase tracking-wide text-[var(--color-ios-label-secondary)]">
          {liked ? "Liked" : "Disliked"} · Step {session.stepNumber} of ~{session.maxSteps}
        </p>

        {/* Progress */}
        <div className="mb-6 h-1.5 w-full overflow-hidden rounded-full bg-white/10">
          <div
            className="h-full rounded-full transition-all duration-300"
            style={{
              width: `${progressPct * 100}%`,
              backgroundColor: liked ? "#f97316" : "#6366f1",
            }}
          />
        </div>

        {session.isComplete ? (
          <div className="flex flex-col items-center gap-3 py-4">
            <Trophy className="h-14 w-14 text-yellow-400" />
            <p className="text-center font-semibold text-[var(--color-ios-label)]">
              Placing &ldquo;{candidate?.title}&rdquo; at #{session.insertionPosition} in your {groupLabel} list
            </p>
          </div>
        ) : (
          <>
            <p className="mb-5 text-center text-[0.9rem] text-[var(--color-ios-label-secondary)]">
              Did you enjoy this more than…
            </p>

            <div className="flex items-center justify-center gap-4">
              {/* Candidate */}
              <div className="flex flex-col items-center gap-2 w-[140px]">
                <span className="text-[0.72rem] font-bold uppercase tracking-wide text-orange-400">
                  You watched
                </span>
                <div className="w-[130px] h-[195px] rounded-xl overflow-hidden bg-[#1a1a1a]">
                  {getPoster(candidate?.poster_path) ? (
                    <img
                      src={getPoster(candidate.poster_path)}
                      alt={candidate.title}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-[rgba(255,255,255,0.4)] text-xs">
                      No Poster
                    </div>
                  )}
                </div>
                <p className="text-center text-[0.8rem] font-semibold leading-tight line-clamp-2">
                  {candidate?.title}
                </p>
                {candidate?.year && (
                  <p className="text-[0.72rem] text-[var(--color-ios-label-secondary)]">
                    {candidate.year}
                  </p>
                )}
              </div>

              <span className="text-[1.4rem] text-[var(--color-ios-label-secondary)]">vs</span>

              {/* Mid movie */}
              {session.midMovie && (
                <div className="flex flex-col items-center gap-2 w-[140px]">
                  <span className="text-[0.72rem] font-bold uppercase tracking-wide text-blue-400">
                    #{session.midMovie.position} · {session.midMovie.score?.toFixed(1)}/10
                  </span>
                  <div className="w-[130px] h-[195px] rounded-xl overflow-hidden bg-[#1a1a1a]">
                    {session.midMovie.poster_path ? (
                      <img
                        src={getPoster(session.midMovie.poster_path)}
                        alt={session.midMovie.title}
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-[rgba(255,255,255,0.4)] text-xs">
                        No Poster
                      </div>
                    )}
                  </div>
                  <p className="text-center text-[0.8rem] font-semibold leading-tight line-clamp-2">
                    {session.midMovie.title}
                  </p>
                  {session.midMovie.year && (
                    <p className="text-[0.72rem] text-[var(--color-ios-label-secondary)]">
                      {session.midMovie.year}
                    </p>
                  )}
                </div>
              )}
            </div>

            <div className="mt-6 flex gap-3">
              <button
                type="button"
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-green-600 py-3 font-bold text-white hover:bg-green-500"
                onClick={session.answerYes}
              >
                <ThumbsUp className="h-4 w-4" />
                Yes, I liked it more
              </button>
              <button
                type="button"
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-red-600 py-3 font-bold text-white hover:bg-red-500"
                onClick={session.answerNo}
              >
                <ThumbsDown className="h-4 w-4" />
                No, I preferred that
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
