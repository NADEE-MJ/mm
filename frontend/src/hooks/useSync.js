/**
 * useSync hook
 * Manages sync status and provides sync controls
 */

import { useState, useEffect } from 'react';
import { getSyncStatus, processQueue, syncFromServer } from '../services/syncQueue';

export function useSync() {
  const [syncStatus, setSyncStatus] = useState({
    status: 'synced',
    pending: 0,
    failed: 0,
    isOnline: navigator.onLine,
    isProcessing: false,
  });

  // Update sync status
  const updateStatus = async () => {
    try {
      const status = await getSyncStatus();
      setSyncStatus(status);
    } catch (err) {
      console.error('Error getting sync status:', err);
    }
  };

  // Poll for sync status
  useEffect(() => {
    updateStatus();

    const interval = setInterval(updateStatus, 5000); // Update every 5 seconds

    // Listen for online/offline events
    const handleOnline = () => {
      updateStatus();
    };

    const handleOffline = () => {
      updateStatus();
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      clearInterval(interval);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  // Manual sync trigger
  const triggerSync = async () => {
    try {
      await processQueue();
      await syncFromServer();
      await updateStatus();
    } catch (err) {
      console.error('Error triggering sync:', err);
    }
  };

  return {
    syncStatus,
    updateStatus,
    triggerSync,
  };
}
