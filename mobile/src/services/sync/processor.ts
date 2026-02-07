import NetInfo from '@react-native-community/netinfo';
import { sendQueueBatch } from '../api/batch';
import { fetchServerChanges } from '../api/sync';
import { getMetadata, setMetadata } from '../database/init';
import { SYNC_CONFIG } from '../../utils/constants';
import { applySyncData } from './resolver';
import {
  getPendingQueue,
  incrementRetries,
  removeFromQueue,
  resetProcessingItems,
  updateQueueStatus,
} from './queue';
import { startSyncWebSocket } from './websocket_listener';

const BATCH_SIZE = 20;

let isProcessing = false;
let syncInterval: ReturnType<typeof setInterval> | null = null;

export async function initSyncProcessor(): Promise<void> {
  await resetProcessingItems();

  NetInfo.addEventListener((state) => {
    if (state.isConnected && state.isInternetReachable) {
      processQueue().catch((error) => console.warn('Sync queue processing failed', error));
    }
  });

  startPeriodicSync();
  await startSyncWebSocket(async () => {
    await pullFromServer();
  });
}

function startPeriodicSync(): void {
  if (syncInterval) {
    clearInterval(syncInterval);
  }
  syncInterval = setInterval(() => {
    processQueue().catch((error) => console.warn('Background sync failed', error));
  }, SYNC_CONFIG.BACKGROUND_INTERVAL);
}

export function stopPeriodicSync(): void {
  if (syncInterval) {
    clearInterval(syncInterval);
    syncInterval = null;
  }
}

export async function processQueue(): Promise<void> {
  if (isProcessing) {
    return;
  }

  const networkState = await NetInfo.fetch();
  if (!networkState.isConnected || !networkState.isInternetReachable) {
    return;
  }

  isProcessing = true;
  try {
    const pendingItems = await getPendingQueue();
    if (pendingItems.length > 0) {
      for (let index = 0; index < pendingItems.length; index += BATCH_SIZE) {
        const batch = pendingItems.slice(index, index + BATCH_SIZE);
        await processBatch(batch);
      }
    }

    await pullFromServer();
  } catch (error) {
    console.error('Sync processor error:', error);
  } finally {
    isProcessing = false;
  }
}

async function processBatch(batch: Awaited<ReturnType<typeof getPendingQueue>>): Promise<void> {
  for (const item of batch) {
    await updateQueueStatus(item.id, 'processing');
  }

  try {
    const response = await sendQueueBatch(batch);
    for (let index = 0; index < batch.length; index += 1) {
      const item = batch[index];
      const result = response.results[index];
      if (!result) {
        await updateQueueStatus(item.id, 'pending');
        continue;
      }

      if (result.success) {
        await removeFromQueue(item.id);
        continue;
      }

      if (result.conflict && result.server_state) {
        await applySyncData({
          movies: [result.server_state],
          people: [],
          lists: [],
          deleted_movie_ids: [],
          has_more: false,
          next_offset: null,
          server_timestamp: response.server_timestamp,
        });
        await removeFromQueue(item.id);
        continue;
      }

      const retries = await incrementRetries(item.id);
      if (retries >= SYNC_CONFIG.MAX_RETRIES) {
        await updateQueueStatus(item.id, 'failed', result.error || 'Sync failed');
      } else {
        await updateQueueStatus(item.id, 'pending', result.error);
      }
    }
  } catch (error) {
    for (const item of batch) {
      const retries = await incrementRetries(item.id);
      if (retries >= SYNC_CONFIG.MAX_RETRIES) {
        await updateQueueStatus(
          item.id,
          'failed',
          error instanceof Error ? error.message : 'Batch sync error'
        );
      } else {
        await updateQueueStatus(item.id, 'pending');
      }
    }
  }
}

export async function pullFromServer(): Promise<void> {
  try {
    const lastSyncRaw = await getMetadata('last_sync');
    const since = lastSyncRaw ? parseFloat(lastSyncRaw) : 0;

    let offset = 0;
    let hasMore = true;
    let maxServerTimestamp = since;

    while (hasMore) {
      const response = await fetchServerChanges(since, 100, offset);
      await applySyncData(response);

      maxServerTimestamp = Math.max(
        maxServerTimestamp,
        response.server_timestamp || response.timestamp || maxServerTimestamp
      );

      hasMore = Boolean(response.has_more);
      offset = response.next_offset || 0;
      if (!hasMore) {
        break;
      }
    }

    await setMetadata('last_sync', String(maxServerTimestamp));
  } catch (error) {
    console.error('Failed to pull from server:', error);
  }
}

export async function forceSyncNow(): Promise<void> {
  await processQueue();
}

export async function getSyncStatus(): Promise<{ lastSync: number; pendingCount: number }> {
  const lastSync = await getMetadata('last_sync');
  const pendingItems = await getPendingQueue();

  return {
    lastSync: lastSync ? parseFloat(lastSync) : 0,
    pendingCount: pendingItems.length,
  };
}
