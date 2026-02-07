import { sendBatchSync } from './sync';
import { BatchSyncResponse, SyncQueueItem } from '../../types';

export async function sendQueueBatch(items: SyncQueueItem[]): Promise<BatchSyncResponse> {
  return sendBatchSync(
    items.map((item) => ({
      action: item.action,
      data: item.data,
      timestamp: item.timestamp,
    }))
  );
}

