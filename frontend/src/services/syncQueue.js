/**
 * Sync queue processor
 * Handles offline sync queue processing and conflict resolution
 */

import { getSyncQueue, updateSyncQueueItem, removeSyncQueueItem, setLastSync } from './storage';
import { api } from './api';

const MAX_RETRIES = 3;
const SYNC_INTERVAL = 30000; // 30 seconds

let syncInterval = null;
let isProcessing = false;

/**
 * Process the sync queue
 * Sends pending actions to the backend
 */
export async function processQueue() {
  if (isProcessing) {
    console.log('Sync already in progress, skipping...');
    return { processed: 0, failed: 0 };
  }

  if (!navigator.onLine) {
    console.log('Offline, skipping sync');
    return { processed: 0, failed: 0, offline: true };
  }

  isProcessing = true;
  let processed = 0;
  let failed = 0;

  try {
    const queue = await getSyncQueue();
    const pendingItems = queue.filter(item => item.status === 'pending' || item.status === 'failed');

    for (const item of pendingItems) {
      if (item.retries >= MAX_RETRIES) {
        console.error(`Max retries reached for item ${item.id}`, item);
        await updateSyncQueueItem(item.id, {
          status: 'failed',
          error: 'Max retries exceeded',
        });
        failed++;
        continue;
      }

      try {
        // Mark as processing
        await updateSyncQueueItem(item.id, { status: 'processing' });

        // Send to backend
        const result = await api.syncProcessAction(item.action, item.data, item.timestamp);

        if (result.success) {
          // Remove from queue on success
          await removeSyncQueueItem(item.id);
          processed++;
          console.log(`Sync successful for action ${item.action}`, result);
        } else {
          // Increment retries on failure
          await updateSyncQueueItem(item.id, {
            status: 'failed',
            retries: item.retries + 1,
            error: result.error || 'Unknown error',
          });
          failed++;
          console.error(`Sync failed for action ${item.action}`, result.error);
        }
      } catch (error) {
        console.error(`Error processing sync item ${item.id}:`, error);
        await updateSyncQueueItem(item.id, {
          status: 'failed',
          retries: item.retries + 1,
          error: error.message,
        });
        failed++;
      }
    }
  } catch (error) {
    console.error('Error processing sync queue:', error);
  } finally {
    isProcessing = false;
  }

  return { processed, failed };
}

/**
 * Sync from server
 * Fetches changes from the server since last sync
 */
export async function syncFromServer() {
  if (!navigator.onLine) {
    console.log('Offline, skipping server sync');
    return { synced: 0, offline: true };
  }

  try {
    const { getLastSync, saveMovie, savePerson } = await import('./storage');
    const lastSync = await getLastSync();

    console.log('Syncing from server since:', lastSync);
    const response = await api.syncGetChanges(lastSync / 1000); // Convert to seconds

    if (response && response.movies) {
      for (const movie of response.movies) {
        // Save to IndexedDB
        await saveMovie({
          imdbId: movie.imdb_id,
          tmdbData: movie.tmdb_data,
          omdbData: movie.omdb_data,
          lastModified: movie.last_modified * 1000, // Convert to milliseconds
          status: movie.status,
          recommendations: movie.recommendations,
          watchHistory: movie.watch_history,
        });
      }

      // Update last sync timestamp
      if (response.timestamp) {
        await setLastSync(response.timestamp * 1000); // Convert to milliseconds
      }

      console.log(`Synced ${response.movies.length} movies from server`);
      return { synced: response.movies.length };
    }

    return { synced: 0 };
  } catch (error) {
    console.error('Error syncing from server:', error);
    return { synced: 0, error: error.message };
  }
}

/**
 * Start automatic sync
 * Runs processQueue and syncFromServer on an interval
 */
export function startAutoSync() {
  if (syncInterval) {
    console.log('Auto-sync already running');
    return;
  }

  console.log('Starting auto-sync');

  // Run immediately
  processQueue();
  syncFromServer();

  // Run on interval
  syncInterval = setInterval(async () => {
    await processQueue();
    await syncFromServer();
  }, SYNC_INTERVAL);

  // Run when coming online
  window.addEventListener('online', () => {
    console.log('Back online, syncing...');
    processQueue();
    syncFromServer();
  });
}

/**
 * Stop automatic sync
 */
export function stopAutoSync() {
  if (syncInterval) {
    clearInterval(syncInterval);
    syncInterval = null;
    console.log('Auto-sync stopped');
  }
}

/**
 * Get sync status
 */
export async function getSyncStatus() {
  const queue = await getSyncQueue();
  const pending = queue.filter(item => item.status === 'pending').length;
  const failed = queue.filter(item => item.status === 'failed').length;
  const isOnline = navigator.onLine;

  let status = 'synced';
  if (!isOnline) {
    status = 'offline';
  } else if (failed > 0) {
    status = 'conflict';
  } else if (pending > 0 || isProcessing) {
    status = 'pending';
  }

  return {
    status,
    pending,
    failed,
    isOnline,
    isProcessing,
  };
}
