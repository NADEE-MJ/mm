/**
 * useSync hook
 * Manages sync status and provides sync controls
 */

import { useState, useEffect, useCallback } from "react";
import {
  getSyncStatus,
  processQueue,
  syncFromServer,
  fullSync,
  addSyncListener,
  retryFailed,
  clearFailed,
} from "../services/syncQueue";

export function useSync() {
  const [syncStatus, setSyncStatus] = useState({
    status: "synced",
    pending: 0,
    failed: 0,
    retrying: 0,
    isOnline: navigator.onLine,
    isProcessing: false,
    isSyncingFromServer: false,
    queueItems: [],
  });
  const [lastSyncTime, setLastSyncTime] = useState(null);

  // Update sync status
  const updateStatus = useCallback(async () => {
    try {
      const status = await getSyncStatus();
      setSyncStatus(status);
    } catch (err) {
      console.error("Error getting sync status:", err);
    }
  }, []);

  // Subscribe to sync status changes and poll
  useEffect(() => {
    updateStatus();

    // Listen to sync events
    const unsubscribe = addSyncListener((status) => {
      setSyncStatus(status);
    });

    // Also poll occasionally as backup
    const interval = setInterval(updateStatus, 10000);

    // Listen for online/offline events
    const handleOnline = () => updateStatus();
    const handleOffline = () => updateStatus();

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      unsubscribe();
      clearInterval(interval);
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, [updateStatus]);

  // Manual sync trigger
  const triggerSync = useCallback(async () => {
    try {
      const result = await fullSync();
      await updateStatus();
      setLastSyncTime(Date.now());
      return result;
    } catch (err) {
      console.error("Error triggering sync:", err);
      throw err;
    }
  }, [updateStatus]);

  // Retry failed items
  const handleRetryFailed = useCallback(async () => {
    try {
      await retryFailed();
      await updateStatus();
    } catch (err) {
      console.error("Error retrying failed:", err);
      throw err;
    }
  }, [updateStatus]);

  // Clear failed items
  const handleClearFailed = useCallback(async () => {
    try {
      await clearFailed();
      await updateStatus();
    } catch (err) {
      console.error("Error clearing failed:", err);
      throw err;
    }
  }, [updateStatus]);

  return {
    syncStatus,
    lastSyncTime,
    updateStatus,
    triggerSync,
    retryFailed: handleRetryFailed,
    clearFailed: handleClearFailed,
  };
}
