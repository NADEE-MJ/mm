/**
 * useRankingSession — pure binary-search ranking hook (no networking).
 *
 * ranked:    full ranked list (liked + disliked); filtered to same liked group at init
 * candidate: the movie being placed
 * liked:     whether the candidate was marked as liked or disliked
 *
 * Algorithm:
 *   lo=0, hi=N  (N = size of same-group snapshot)
 *   mid=(lo+hi)//2
 *   YES → hi=mid   (candidate beats mid → search left)
 *   NO  → lo=mid+1 (mid beats candidate → search right)
 *   done when lo>=hi, insert at position lo+1 (1-indexed within the group)
 */

import { useState, useRef } from "react";

export function useRankingSession(ranked: any[], candidate: any, liked: boolean, excludeImdbId?: string) {
  // Snapshot filtered to the same liked/disliked group (and excluding the candidate itself for re-ranks)
  const snapshotRef = useRef<any[]>(
    ranked.filter((r) => r.liked === liked && r.imdb_id !== excludeImdbId)
  );
  const snapshot = snapshotRef.current;

  const [lo, setLo] = useState(0);
  const [hi, setHi] = useState(snapshot.length);
  const [stepCount, setStepCount] = useState(0);

  const mid = Math.floor((lo + hi) / 2);
  const midMovie: any | null = lo < hi && snapshot[mid] !== undefined ? snapshot[mid] : null;
  const insertionPosition = lo + 1; // 1-indexed within the liked/disliked group
  const maxSteps = snapshot.length > 0 ? Math.ceil(Math.log2(snapshot.length + 1)) : 1;
  const stepNumber = stepCount + 1;

  function answerYes() {
    if (lo >= hi) return;
    setHi(mid);
    setStepCount((s) => s + 1);
  }

  function answerNo() {
    if (lo >= hi) return;
    setLo(mid + 1);
    setStepCount((s) => s + 1);
  }

  return {
    midMovie,
    isComplete: lo >= hi,
    insertionPosition,
    answerYes,
    answerNo,
    stepNumber,
    maxSteps,
  };
}
