/**
 * RankedListView — shows liked and disliked sub-lists separately.
 *
 * Liked:    scores (5, 10] — ordered best → least liked
 * Disliked: scores [1, 5]  — ordered least bad → worst
 */

import { useState } from "react";
import { Trophy, Trash2, Film, ThumbsUp, ThumbsDown, RefreshCw } from "lucide-react";
import { getPoster } from "../../../utils/helpers";
import { useRankingContext } from "../../../contexts/RankingContext";
import RankingComparisonDialog from "./RankingComparisonDialog";

function RankingRow({
  entry,
  onRemove,
  onRerank,
  removing,
}: {
  entry: any;
  onRemove: () => void;
  onRerank: () => void;
  removing: boolean;
}) {
  const poster = getPoster(entry.poster_path);
  return (
    <li className="flex items-center gap-3 px-3 py-2.5">
      <span className="inline-flex h-6 min-w-[28px] items-center justify-center rounded-full bg-[var(--color-ios-blue)] px-1.5 text-[0.7rem] font-bold text-white flex-shrink-0">
        #{entry.position}
      </span>

      <div className="h-[58px] w-10 flex-shrink-0 overflow-hidden rounded-lg bg-[#1a1a1a]">
        {poster ? (
          <img src={poster} alt={entry.title} className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <Film className="h-4 w-4 opacity-30" />
          </div>
        )}
      </div>

      <div className="min-w-0 flex-1">
        <p className="truncate text-[0.88rem] font-semibold text-[var(--color-ios-label)]">
          {entry.title}
        </p>
        <div className="flex items-center gap-1 text-[0.72rem] text-blue-400">
          <Trophy className="h-3 w-3" />
          <span>{entry.score?.toFixed(1)}/10</span>
          {entry.year && (
            <span className="text-[var(--color-ios-label-secondary)]">· {entry.year}</span>
          )}
        </div>
      </div>

      <div className="flex items-center gap-1">
        <button
          type="button"
          className="rounded-lg p-1.5 text-[var(--color-ios-label-secondary)] hover:bg-white/10 hover:text-[var(--color-ios-label)] disabled:opacity-40"
          onClick={onRerank}
          disabled={removing}
          aria-label={`Re-rank ${entry.title}`}
        >
          <RefreshCw className="h-4 w-4" />
        </button>
        <button
          type="button"
          className="rounded-lg p-1.5 text-[var(--color-ios-label-secondary)] hover:bg-red-500/20 hover:text-red-400 disabled:opacity-40"
          onClick={onRemove}
          disabled={removing}
          aria-label={`Remove ${entry.title} from ranking`}
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>
    </li>
  );
}

export default function RankedListView() {
  const { ranked, removeFromRanking, insertAtPosition, loading } = useRankingContext();
  const [removing, setRemoving] = useState<string | null>(null);

  // Re-rank flow: step 1 = liked/disliked prompt, step 2 = comparison dialog
  const [pendingRerank, setPendingRerank] = useState<any>(null);
  const [activeRerank, setActiveRerank] = useState<{ entry: any; liked: boolean } | null>(null);

  const handleRemove = async (imdbId: string) => {
    setRemoving(imdbId);
    try {
      await removeFromRanking(imdbId);
    } catch (err) {
      console.error("Failed to remove ranking:", err);
    } finally {
      setRemoving(null);
    }
  };

  const handleRerankChoice = (liked: boolean) => {
    if (!pendingRerank) return;
    setActiveRerank({ entry: pendingRerank, liked });
    setPendingRerank(null);
  };

  const handleRerankComplete = async (position: number) => {
    if (!activeRerank) return;
    const { entry, liked } = activeRerank;
    setActiveRerank(null);
    try {
      await removeFromRanking(entry.imdb_id);
      await insertAtPosition(entry.imdb_id, position, liked);
    } catch (err) {
      console.error("Failed to re-rank:", err);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20 text-[var(--color-ios-label-secondary)]">
        Loading…
      </div>
    );
  }

  const likedEntries = ranked.filter((e: any) => e.liked);
  const dislikedEntries = ranked.filter((e: any) => !e.liked);

  if (likedEntries.length === 0 && dislikedEntries.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-3 py-20 text-[var(--color-ios-label-secondary)]">
        <Trophy className="h-12 w-12 opacity-40" />
        <p className="text-sm">No rankings yet. Start ranking your watched movies!</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <h2 className="text-[1.1rem] font-bold text-[var(--color-ios-label)]">My Rankings</h2>

      {likedEntries.length > 0 && (
        <div>
          <div className="mb-1.5 flex items-center gap-1.5 text-[0.75rem] font-semibold uppercase tracking-wide text-green-400">
            <ThumbsUp className="h-3.5 w-3.5" />
            Liked · {likedEntries.length} movie{likedEntries.length !== 1 ? "s" : ""}
          </div>
          <ul className="divide-y divide-[var(--color-ios-separator)] rounded-2xl border border-[var(--color-ios-separator)] bg-[rgba(28,28,28,0.94)] overflow-hidden">
            {likedEntries.map((entry: any) => (
              <RankingRow
                key={entry.imdb_id}
                entry={entry}
                onRemove={() => handleRemove(entry.imdb_id)}
                onRerank={() => setPendingRerank(entry)}
                removing={removing === entry.imdb_id}
              />
            ))}
          </ul>
        </div>
      )}

      {dislikedEntries.length > 0 && (
        <div>
          <div className="mb-1.5 flex items-center gap-1.5 text-[0.75rem] font-semibold uppercase tracking-wide text-[var(--color-ios-label-secondary)]">
            <ThumbsDown className="h-3.5 w-3.5" />
            Didn't Like · {dislikedEntries.length} movie{dislikedEntries.length !== 1 ? "s" : ""}
          </div>
          <ul className="divide-y divide-[var(--color-ios-separator)] rounded-2xl border border-[var(--color-ios-separator)] bg-[rgba(28,28,28,0.94)] overflow-hidden">
            {dislikedEntries.map((entry: any) => (
              <RankingRow
                key={entry.imdb_id}
                entry={entry}
                onRemove={() => handleRemove(entry.imdb_id)}
                onRerank={() => setPendingRerank(entry)}
                removing={removing === entry.imdb_id}
              />
            ))}
          </ul>
        </div>
      )}

      {/* Step 1: Liked / Didn't Like prompt */}
      {pendingRerank && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm sm:items-center">
          <div className="w-full max-w-sm rounded-t-2xl border border-[var(--color-ios-separator)] bg-[rgba(22,22,22,0.98)] p-5 shadow-2xl sm:rounded-2xl">
            <div className="mb-4 flex items-center gap-3">
              {getPoster(pendingRerank.poster_path) && (
                <img
                  src={getPoster(pendingRerank.poster_path)}
                  alt={pendingRerank.title}
                  className="h-14 w-10 rounded-lg object-cover flex-shrink-0"
                />
              )}
              <div className="min-w-0">
                <p className="text-[0.72rem] font-semibold uppercase tracking-wide text-[var(--color-ios-label-secondary)]">
                  Re-rank — did you like this?
                </p>
                <p className="truncate font-bold text-[var(--color-ios-label)]">
                  {pendingRerank.title}
                </p>
                {pendingRerank.year && (
                  <p className="text-[0.75rem] text-[var(--color-ios-label-secondary)]">
                    {pendingRerank.year}
                  </p>
                )}
              </div>
            </div>
            <div className="flex gap-3">
              <button
                type="button"
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-green-600 py-3 font-bold text-white hover:bg-green-500"
                onClick={() => handleRerankChoice(true)}
              >
                <ThumbsUp className="h-4 w-4" />
                Liked It
              </button>
              <button
                type="button"
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[rgba(255,255,255,0.08)] py-3 font-bold text-[var(--color-ios-label)] hover:bg-white/15"
                onClick={() => handleRerankChoice(false)}
              >
                <ThumbsDown className="h-4 w-4" />
                Didn't Like
              </button>
            </div>
            <button
              type="button"
              className="mt-3 w-full rounded-xl py-2.5 text-[0.85rem] text-[var(--color-ios-label-secondary)] hover:bg-white/5"
              onClick={() => setPendingRerank(null)}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Step 2: Binary comparison */}
      {activeRerank && (
        <RankingComparisonDialog
          isOpen={true}
          onClose={() => setActiveRerank(null)}
          candidate={activeRerank.entry}
          ranked={ranked}
          liked={activeRerank.liked}
          excludeImdbId={activeRerank.entry.imdb_id}
          onComplete={handleRerankComplete}
        />
      )}
    </div>
  );
}
