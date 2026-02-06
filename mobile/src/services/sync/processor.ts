import NetInfo from '@react-native-community/netinfo';
import {
  getPendingQueue,
  updateQueueStatus,
  incrementRetries,
  removeFromQueue,
  resetProcessingItems,
} from './queue';
import { sendSyncAction, fetchServerChanges } from '../api/sync';
import { getMetadata, setMetadata } from '../database/init';
import { SYNC_CONFIG } from '../../utils/constants';
import { isNetworkError } from '../api/client';
import { applySyncData } from './resolver';

let isProcessing = false;
let syncInterval: NodeJS.Timeout | null = null;

/**
 * Initialize sync processor
 */
export async function initSyncProcessor(): Promise<void> {
  // Reset any items stuck in processing state
  await resetProcessingItems();

  // Listen for network changes
  NetInfo.addEventListener((state) => {
    if (state.isConnected && state.isInternetReachable) {
      console.log('Network available - starting sync');
      processQueue();
    }
  });

  // Start periodic sync (every 30 seconds when app is active)
  startPeriodicSync();
}

/**
 * Start periodic sync
 */
function startPeriodicSync(): void {
  if (syncInterval) {
    clearInterval(syncInterval);
  }

  syncInterval = setInterval(() => {
    processQueue();
  }, SYNC_CONFIG.BACKGROUND_INTERVAL / 60); // 30 seconds
}

/**
 * Stop periodic sync
 */
export function stopPeriodicSync(): void {
  if (syncInterval) {
    clearInterval(syncInterval);
    syncInterval = null;
  }
}

/**
 * Process sync queue
 */
export async function processQueue(): Promise<void> {
  // Prevent concurrent processing
  if (isProcessing) {
    console.log('Sync already in progress');
    return;
  }

  // Check network connectivity
  const networkState = await NetInfo.fetch();
  if (!networkState.isConnected || !networkState.isInternetReachable) {
    console.log('No network connection - skipping sync');
    return;
  }

  isProcessing = true;

  try {
    console.log('Starting sync queue processing');

    // Get pending items
    const pendingItems = await getPendingQueue();

    if (pendingItems.length === 0) {
      console.log('No pending items to sync');
      // Still pull from server
      await pullFromServer();
      return;
    }

    console.log(`Processing ${pendingItems.length} pending items`);

    // Process each item sequentially (chronological order)
    for (const item of pendingItems) {
      try {
        // Mark as processing
        await updateQueueStatus(item.id, 'processing');

        // Send to server
        const response = await sendSyncAction(
          item.action,
          item.data,
          item.timestamp
        );

        if (response.success) {
          // Success - remove from queue
          console.log(`Sync success: ${item.action} for ${item.data.imdb_id || 'unknown'}`);
          await removeFromQueue(item.id);
        } else if (response.conflict) {
          // Conflict - server has newer data
          console.log(`Conflict detected for ${item.action} - applying server state`);

          // Apply server state if provided
          if (response.current_state) {
            await applySyncData({
              movies: response.current_state.movies || [],
              recommendations: response.current_state.recommendations || [],
              watch_history: response.current_state.watch_history || [],
              movie_status: response.current_state.movie_status || [],
              people: response.current_state.people || [],
              custom_lists: response.current_state.custom_lists || [],
              server_timestamp: Date.now(),
            });
          }

          // Remove from queue (conflict resolved)
          await removeFromQueue(item.id);
        } else {
          // Unknown failure
          throw new Error('Sync failed without conflict');
        }
      } catch (error) {
        console.error(`Failed to sync item ${item.id}:`, error);

        // Increment retries
        const newRetries = await incrementRetries(item.id);

        if (newRetries >= SYNC_CONFIG.MAX_RETRIES) {
          // Max retries reached - mark as failed
          await updateQueueStatus(
            item.id,
            'failed',
            error instanceof Error ? error.message : 'Unknown error'
          );
        } else {
          // Mark as pending for retry
          await updateQueueStatus(item.id, 'pending');

          // Wait before next retry (exponential backoff)
          const delay = SYNC_CONFIG.RETRY_DELAYS[newRetries - 1] || 15000;
          await new Promise((resolve) => setTimeout(resolve, delay));
        }
      }
    }

    // Pull changes from server
    await pullFromServer();

    console.log('Sync queue processing completed');
  } catch (error) {
    console.error('Sync processor error:', error);
  } finally {
    isProcessing = false;
  }
}

/**
 * Pull changes from server since last sync
 */
async function pullFromServer(): Promise<void> {
  try {
    const lastSync = await getMetadata('last_sync');
    const since = lastSync ? parseInt(lastSync, 10) : 0;

    console.log(`Pulling server changes since ${since}`);

    const serverData = await fetchServerChanges(since);

    // Apply server changes
    await applySyncData(serverData);

    // Update last sync timestamp
    await setMetadata('last_sync', serverData.server_timestamp.toString());

    console.log('Server changes applied successfully');
  } catch (error) {
    console.error('Failed to pull from server:', error);
  }
}

/**
 * Force sync now (manual trigger)
 */
export async function forceSyncNow(): Promise<void> {
  console.log('Force sync triggered');
  await processQueue();
}

/**
 * Get sync status
 */
export async function getSyncStatus(): Promise<{
  lastSync: number;
  pendingCount: number;
}> {
  const lastSync = await getMetadata('last_sync');
  const pendingItems = await getPendingQueue();

  return {
    lastSync: lastSync ? parseInt(lastSync, 10) : 0,
    pendingCount: pendingItems.length,
  };
}
