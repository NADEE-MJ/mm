/**
 * Sync queue processor
 * Handles offline sync queue processing and conflict resolution
 */

import {
  getSyncQueue,
  updateSyncQueueItem,
  removeSyncQueueItem,
  setLastSync,
  getLastSync,
  saveMovie,
  savePerson,
  getAllMovies,
} from "./storage";
import { api } from "./api";

const MAX_RETRIES = 3;
const SYNC_INTERVAL = 30000; // 30 seconds

let syncInterval = null;
let isProcessing = false;
let isSyncingFromServer = false;

// Event emitter for sync status updates
const syncListeners = new Set();

export function addSyncListener(callback) {
  syncListeners.add(callback);
  return () => syncListeners.delete(callback);
}

function notifySyncListeners() {
  getSyncStatus().then((status) => {
    syncListeners.forEach((callback) => callback(status));
  });
}

/**
 * Process the sync queue
 * Sends pending actions to the backend
 */
export async function processQueue() {
  if (isProcessing) {
    console.log("Sync already in progress, skipping...");
    return { processed: 0, failed: 0 };
  }

  if (!navigator.onLine) {
    console.log("Offline, skipping sync");
    notifySyncListeners();
    return { processed: 0, failed: 0, offline: true };
  }

  isProcessing = true;
  notifySyncListeners();

  let processed = 0;
  let failed = 0;

  try {
    const queue = await getSyncQueue();
    // Sort by timestamp to process in order
    const pendingItems = queue
      .filter((item) => item.status === "pending" || item.status === "failed")
      .sort((a, b) => a.timestamp - b.timestamp);

    console.log(`Processing ${pendingItems.length} sync items...`);

    for (const item of pendingItems) {
      if (item.retries >= MAX_RETRIES) {
        console.error(`Max retries reached for item ${item.id}`, item);
        await updateSyncQueueItem(item.id, {
          status: "failed",
          error: "Max retries exceeded",
        });
        failed++;
        continue;
      }

      try {
        // Mark as processing
        await updateSyncQueueItem(item.id, { status: "processing" });
        notifySyncListeners();

        // Send to backend
        const result = await api.syncProcessAction(item.action, item.data, item.timestamp);

        if (result.success) {
          // Remove from queue on success
          await removeSyncQueueItem(item.id);
          processed++;
          console.log(`✓ Sync successful for action ${item.action}`, result);

          // Update local movie's lastModified if returned
          if (result.last_modified && item.data.imdb_id) {
            try {
              const movies = await getAllMovies();
              const movie = movies.find((m) => m.imdbId === item.data.imdb_id);
              if (movie) {
                movie.lastModified = result.last_modified * 1000;
                await saveMovie(movie);
              }
            } catch (e) {
              console.warn("Could not update local lastModified:", e);
            }
          }
        } else {
          // Increment retries on failure
          await updateSyncQueueItem(item.id, {
            status: "failed",
            retries: item.retries + 1,
            error: result.error || "Unknown error",
          });
          failed++;
          console.error(`✗ Sync failed for action ${item.action}:`, result.error);
        }
      } catch (error) {
        console.error(`Error processing sync item ${item.id}:`, error);
        await updateSyncQueueItem(item.id, {
          status: "failed",
          retries: item.retries + 1,
          error: error.message,
        });
        failed++;
      }
    }
  } catch (error) {
    console.error("Error processing sync queue:", error);
  } finally {
    isProcessing = false;
    notifySyncListeners();
  }

  return { processed, failed };
}

/**
 * Sync from server
 * Fetches changes from the server since last sync and merges with local data
 */
export async function syncFromServer() {
  if (!navigator.onLine) {
    console.log("Offline, skipping server sync");
    return { synced: 0, offline: true };
  }

  if (isSyncingFromServer) {
    console.log("Already syncing from server, skipping...");
    return { synced: 0, skipped: true };
  }

  isSyncingFromServer = true;
  notifySyncListeners();

  try {
    const lastSync = await getLastSync();
    const lastSyncSeconds = lastSync ? lastSync / 1000 : 0;

    console.log("Syncing from server since:", new Date(lastSync || 0).toISOString());

    const response = await api.syncGetChanges(lastSyncSeconds);

    if (response && response.movies && response.movies.length > 0) {
      console.log(`Received ${response.movies.length} movies from server`);

      // Get current local movies for merge comparison
      const localMovies = await getAllMovies();
      const localMoviesMap = new Map(localMovies.map((m) => [m.imdbId, m]));

      for (const serverMovie of response.movies) {
        const imdbId = serverMovie.imdb_id;
        const localMovie = localMoviesMap.get(imdbId);
        const serverTimestamp = serverMovie.last_modified * 1000;

        // Conflict resolution: server wins if server timestamp is newer
        const shouldUpdate =
          !localMovie || !localMovie.lastModified || serverTimestamp >= localMovie.lastModified;

        if (shouldUpdate) {
          // Transform server data to local format
          const movieData = {
            imdbId: serverMovie.imdb_id,
            tmdbData: serverMovie.tmdb_data,
            omdbData: serverMovie.omdb_data,
            lastModified: serverTimestamp,
            status: serverMovie.status || "toWatch",
            recommendations:
              serverMovie.recommendations?.map((r) => ({
                id: r.id,
                person: r.person,
                date_recommended: r.date_recommended,
              })) || [],
            watchHistory: serverMovie.watch_history
              ? {
                  imdbId: serverMovie.watch_history.imdb_id,
                  dateWatched: serverMovie.watch_history.date_watched * 1000,
                  myRating: serverMovie.watch_history.my_rating,
                }
              : null,
          };

          await saveMovie(movieData);
          console.log(`✓ Updated movie: ${imdbId}`);
        } else {
          console.log(`→ Skipped movie ${imdbId} (local is newer)`);
        }
      }

      // Update last sync timestamp
      if (response.timestamp) {
        await setLastSync(response.timestamp * 1000);
      }

      console.log(`Sync complete: ${response.movies.length} movies processed`);
      return { synced: response.movies.length };
    }

    // Update last sync even if no movies
    if (response && response.timestamp) {
      await setLastSync(response.timestamp * 1000);
    }

    return { synced: 0 };
  } catch (error) {
    console.error("Error syncing from server:", error);
    return { synced: 0, error: error.message };
  } finally {
    isSyncingFromServer = false;
    notifySyncListeners();
  }
}

/**
 * Full sync - process queue then sync from server
 */
export async function fullSync() {
  const queueResult = await processQueue();
  const serverResult = await syncFromServer();

  return {
    queue: queueResult,
    server: serverResult,
  };
}

/**
 * Start automatic sync
 * Runs processQueue and syncFromServer on an interval
 */
export function startAutoSync() {
  if (syncInterval) {
    console.log("Auto-sync already running");
    return;
  }

  console.log("Starting auto-sync...");

  // Run immediately
  fullSync();

  // Run on interval
  syncInterval = setInterval(() => {
    fullSync();
  }, SYNC_INTERVAL);

  // Run when coming online
  const handleOnline = () => {
    console.log("Back online, triggering sync...");
    fullSync();
  };

  const handleOffline = () => {
    console.log("Went offline");
    notifySyncListeners();
  };

  // Listen for service worker sync requests
  const handleSWSync = () => {
    console.log("Service worker requested sync");
    fullSync();
  };

  window.addEventListener("online", handleOnline);
  window.addEventListener("offline", handleOffline);
  window.addEventListener("sw-sync-requested", handleSWSync);

  // Store cleanup function
  startAutoSync._cleanup = () => {
    window.removeEventListener("online", handleOnline);
    window.removeEventListener("offline", handleOffline);
  };
}

/**
 * Stop automatic sync
 */
export function stopAutoSync() {
  if (syncInterval) {
    clearInterval(syncInterval);
    syncInterval = null;
    console.log("Auto-sync stopped");
  }
  if (startAutoSync._cleanup) {
    startAutoSync._cleanup();
    startAutoSync._cleanup = null;
  }
}

/**
 * Get sync status
 */
export async function getSyncStatus() {
  const queue = await getSyncQueue();
  const pending = queue.filter(
    (item) => item.status === "pending" || item.status === "processing",
  ).length;
  const failed = queue.filter(
    (item) => item.status === "failed" && item.retries >= MAX_RETRIES,
  ).length;
  const retrying = queue.filter(
    (item) => item.status === "failed" && item.retries < MAX_RETRIES,
  ).length;
  const isOnline = navigator.onLine;

  let status = "synced";
  if (!isOnline) {
    status = "offline";
  } else if (failed > 0) {
    status = "error";
  } else if (retrying > 0) {
    status = "retrying";
  } else if (pending > 0 || isProcessing || isSyncingFromServer) {
    status = "syncing";
  }

  return {
    status,
    pending,
    failed,
    retrying,
    isOnline,
    isProcessing,
    isSyncingFromServer,
    queueItems: queue,
    isProcessing,
  };
}

/**
 * Retry all failed sync items
 */
export async function retryFailed() {
  const queue = await getSyncQueue();
  const failedItems = queue.filter(
    (item) => item.status === "failed" && item.retries >= MAX_RETRIES,
  );

  for (const item of failedItems) {
    await updateSyncQueueItem(item.id, {
      status: "pending",
      retries: 0,
      error: null,
    });
  }

  notifySyncListeners();

  // Trigger processing
  if (failedItems.length > 0) {
    processQueue();
  }

  return failedItems.length;
}

/**
 * Clear all failed sync items
 */
export async function clearFailed() {
  const queue = await getSyncQueue();
  const failedItems = queue.filter(
    (item) => item.status === "failed" && item.retries >= MAX_RETRIES,
  );

  for (const item of failedItems) {
    await removeSyncQueueItem(item.id);
  }

  notifySyncListeners();
  return failedItems.length;
}
