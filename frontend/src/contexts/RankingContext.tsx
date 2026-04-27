/**
 * RankingContext — server-backed ranked / unranked movie state.
 * Follows the same pattern as MoviesContext.tsx.
 */

import { createContext, useContext, useState, useEffect, useCallback } from "react";
import api from "../services/api";
import { useAuth } from "./AuthContext";

const RankingContext = createContext(null);

export function RankingProvider({ children }) {
  const { isAuthenticated } = useAuth();
  const [ranked, setRanked] = useState([]);
  const [unranked, setUnranked] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadRankingData = useCallback(async () => {
    if (!isAuthenticated) {
      setRanked([]);
      setUnranked([]);
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      const [rankedData, unrankedData] = await Promise.all([
        api.getRanking(),
        api.getUnranked(),
      ]);
      setRanked(rankedData || []);
      setUnranked(unrankedData || []);
    } catch (err) {
      console.error("Error loading ranking data:", err);
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    loadRankingData();
  }, [loadRankingData]);

  // Refresh when WebSocket broadcasts a movie change
  useEffect(() => {
    const handler = () => loadRankingData();
    window.addEventListener("mm-sync-event", handler);
    window.addEventListener("mm-force-refresh", handler);
    return () => {
      window.removeEventListener("mm-sync-event", handler);
      window.removeEventListener("mm-force-refresh", handler);
    };
  }, [loadRankingData]);

  const insertAtPosition = useCallback(
    async (imdbId: string, position: number, liked: boolean) => {
      await api.insertRanking(imdbId, position, liked);
      await loadRankingData();
    },
    [loadRankingData],
  );

  const removeFromRanking = useCallback(
    async (imdbId) => {
      await api.removeRanking(imdbId);
      await loadRankingData();
    },
    [loadRankingData],
  );

  const value = {
    ranked,
    unranked,
    loading,
    loadRankingData,
    insertAtPosition,
    removeFromRanking,
  };

  return <RankingContext.Provider value={value}>{children}</RankingContext.Provider>;
}

export function useRankingContext() {
  const context = useContext(RankingContext);
  if (!context) {
    throw new Error("useRankingContext must be used within a RankingProvider");
  }
  return context;
}
