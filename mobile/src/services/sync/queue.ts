import { getDatabase } from '../database/init';
import { SyncQueueItem, SyncAction } from '../../types';

/**
 * Add item to sync queue
 */
export async function addToQueue(
  action: SyncAction,
  data: any
): Promise<number> {
  try {
    const db = getDatabase();
    const timestamp = Date.now();

    const result = await db.runAsync(
      `INSERT INTO sync_queue (action, data, timestamp, status, retries, created_at)
       VALUES (?, ?, ?, 'pending', 0, ?)`,
      [action, JSON.stringify(data), timestamp, timestamp]
    );

    return result.lastInsertRowId;
  } catch (error) {
    console.error('Failed to add to sync queue:', error);
    throw error;
  }
}

/**
 * Get pending queue items (ordered by timestamp for chronological processing)
 */
export async function getPendingQueue(): Promise<SyncQueueItem[]> {
  try {
    const db = getDatabase();
    const rows = await db.getAllAsync<any>(
      `SELECT * FROM sync_queue
       WHERE status = 'pending'
       ORDER BY timestamp ASC`
    );

    return rows.map((row) => ({
      id: row.id,
      action: row.action,
      data: JSON.parse(row.data),
      timestamp: row.timestamp,
      status: row.status,
      retries: row.retries,
      error: row.error,
      created_at: row.created_at,
    }));
  } catch (error) {
    console.error('Failed to get pending queue:', error);
    return [];
  }
}

/**
 * Get all queue items (for debugging)
 */
export async function getAllQueue(): Promise<SyncQueueItem[]> {
  try {
    const db = getDatabase();
    const rows = await db.getAllAsync<any>(
      'SELECT * FROM sync_queue ORDER BY timestamp ASC'
    );

    return rows.map((row) => ({
      id: row.id,
      action: row.action,
      data: JSON.parse(row.data),
      timestamp: row.timestamp,
      status: row.status,
      retries: row.retries,
      error: row.error,
      created_at: row.created_at,
    }));
  } catch (error) {
    console.error('Failed to get all queue:', error);
    return [];
  }
}

/**
 * Update queue item status
 */
export async function updateQueueStatus(
  id: number,
  status: 'pending' | 'processing' | 'failed',
  error?: string
): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      'UPDATE sync_queue SET status = ?, error = ? WHERE id = ?',
      [status, error || null, id]
    );
  } catch (error) {
    console.error('Failed to update queue status:', error);
    throw error;
  }
}

/**
 * Increment retry count for queue item
 */
export async function incrementRetries(id: number): Promise<number> {
  try {
    const db = getDatabase();

    // Get current retries
    const result = await db.getFirstAsync<{ retries: number }>(
      'SELECT retries FROM sync_queue WHERE id = ?',
      [id]
    );

    const newRetries = (result?.retries || 0) + 1;

    // Update retries
    await db.runAsync(
      'UPDATE sync_queue SET retries = ? WHERE id = ?',
      [newRetries, id]
    );

    return newRetries;
  } catch (error) {
    console.error('Failed to increment retries:', error);
    throw error;
  }
}

/**
 * Remove item from queue
 */
export async function removeFromQueue(id: number): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync('DELETE FROM sync_queue WHERE id = ?', [id]);
  } catch (error) {
    console.error('Failed to remove from queue:', error);
    throw error;
  }
}

/**
 * Clear all failed items from queue
 */
export async function clearFailedQueue(): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync("DELETE FROM sync_queue WHERE status = 'failed'");
  } catch (error) {
    console.error('Failed to clear failed queue:', error);
    throw error;
  }
}

/**
 * Get count of pending items
 */
export async function getPendingCount(): Promise<number> {
  try {
    const db = getDatabase();
    const result = await db.getFirstAsync<{ count: number }>(
      "SELECT COUNT(*) as count FROM sync_queue WHERE status = 'pending'"
    );

    return result?.count || 0;
  } catch (error) {
    console.error('Failed to get pending count:', error);
    return 0;
  }
}

/**
 * Reset processing items back to pending (in case app crashed during sync)
 */
export async function resetProcessingItems(): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      "UPDATE sync_queue SET status = 'pending' WHERE status = 'processing'"
    );
  } catch (error) {
    console.error('Failed to reset processing items:', error);
    throw error;
  }
}

/**
 * Replace a temporary imdb_id in pending queue items.
 */
export async function remapQueueImdbId(oldImdbId: string, newImdbId: string): Promise<void> {
  try {
    const db = getDatabase();
    const rows = await db.getAllAsync<any>(
      `SELECT id, data FROM sync_queue
       WHERE status IN ('pending', 'processing', 'failed')`
    );

    for (const row of rows) {
      let parsed: any;
      try {
        parsed = JSON.parse(row.data);
      } catch {
        continue;
      }
      if (parsed?.imdb_id !== oldImdbId) {
        continue;
      }
      parsed.imdb_id = newImdbId;
      await db.runAsync('UPDATE sync_queue SET data = ? WHERE id = ?', [
        JSON.stringify(parsed),
        row.id,
      ]);
    }
  } catch (error) {
    console.error('Failed to remap queue imdb_id:', error);
    throw error;
  }
}
