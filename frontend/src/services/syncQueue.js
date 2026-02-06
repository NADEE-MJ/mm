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
  getMovie,
  getAllPeople,
  deletePerson,
} from "./storage";
import { api } from "./api";
import { getAuthToken } from "../contexts/AuthContext";

const MAX_RETRIES = 3;
const SYNC_INTERVAL = 30000; // 30 seconds
const WS_RECONNECT_DELAY = 5000;

let syncInterval = null;
let isProcessing = false;
let isSyncingFromServer = false;
let syncSocket = null;
let wsReconnectTimeout = null;
let wsConnected = false;
let realtimeSyncTimeout = null;

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

function transformServerMovie(serverMovie) {
  if (!serverMovie) return null;

  const serverTimestamp = (serverMovie.last_modified || serverMovie.lastModified || 0) * 1000;
  return {
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
        vote_type: r.vote_type || "upvote",  // Default to upvote for backwards compat
      })) || [],
    watchHistory: serverMovie.watch_history
      ? {
          imdbId: serverMovie.watch_history.imdb_id,
          dateWatched: serverMovie.watch_history.date_watched * 1000,
          myRating: serverMovie.watch_history.my_rating,
        }
      : null,
  };
}

async function upsertMovieFromServer(serverMovie) {
  const normalized = transformServerMovie(serverMovie);
  if (!normalized) return;
  await saveMovie(normalized, { preserveTimestamp: true });
}

async function updateLocalMovieTimestamp(imdbId, serverTimestamp) {
  if (!imdbId || !serverTimestamp) return;
  try {
    const movie = await getMovie(imdbId);
    if (!movie) return;
    movie.lastModified = serverTimestamp * 1000;
    await saveMovie(movie, { preserveTimestamp: true });
  } catch (error) {
    console.warn("Could not update local lastModified:", error);
  }
}

async function mergePeopleFromServer(people = []) {
  const existing = await getAllPeople();
  const existingMap = new Map(existing.map((person) => [person.name, person]));
  const incomingNames = new Set();

  for (const person of people) {
    if (!person?.name) continue;
    incomingNames.add(person.name);
    await savePerson({
      name: person.name,
      is_trusted: person.is_trusted ?? false,
      is_default: person.is_default ?? false,
      color: person.color || "#0a84ff",
      emoji: person.emoji || null,
    });
  }

  for (const [name, person] of existingMap.entries()) {
    if (!incomingNames.has(name) && !person.is_default) {
      await deletePerson(name);
    }
  }
}

function getWebSocketUrl(token) {
  const base = (import.meta.env.VITE_API_URL || window.location.origin).replace(/\/$/, "");
  const protocol = base.startsWith("https") ? "wss" : "ws";
  const wsBase = base.replace(/^https?/, protocol);
  return `${wsBase}/ws/sync?token=${encodeURIComponent(token)}`;
}

function teardownWebSocket() {
  if (syncSocket) {
    try {
      syncSocket.close();
    } catch (error) {
      console.warn("Error closing sync socket", error);
    }
    syncSocket = null;
  }
  if (wsReconnectTimeout) {
    clearTimeout(wsReconnectTimeout);
    wsReconnectTimeout = null;
  }
  if (realtimeSyncTimeout) {
    clearTimeout(realtimeSyncTimeout);
    realtimeSyncTimeout = null;
  }
  if (wsConnected) {
    wsConnected = false;
    notifySyncListeners();
  }
}

function scheduleWebSocketReconnect() {
  if (wsReconnectTimeout || !navigator.onLine) return;
  wsReconnectTimeout = setTimeout(() => {
    wsReconnectTimeout = null;
    ensureWebSocketConnection();
  }, WS_RECONNECT_DELAY);
}

function scheduleRealtimeSync() {
  if (realtimeSyncTimeout) return;
  realtimeSyncTimeout = setTimeout(() => {
    realtimeSyncTimeout = null;
    fullSync().catch((error) => console.error("Realtime sync failed", error));
  }, 250);
}

function handleWebSocketMessage(event) {
  try {
    const data = JSON.parse(event.data);
    if (data.type === "movieUpdated" || data.type === "peopleUpdated") {
      scheduleRealtimeSync();
    }
  } catch (error) {
    console.warn("Invalid sync websocket payload", error);
  }
}

export function ensureWebSocketConnection() {
  if (syncSocket || !navigator.onLine) return;
  const token = getAuthToken();
  if (!token) return;

  try {
    const wsUrl = getWebSocketUrl(token);
    syncSocket = new WebSocket(wsUrl);
  } catch (error) {
    console.error("Unable to open sync websocket", error);
    scheduleWebSocketReconnect();
    return;
  }

  syncSocket.addEventListener("open", () => {
    wsConnected = true;
    notifySyncListeners();
  });

  syncSocket.addEventListener("message", handleWebSocketMessage);

  syncSocket.addEventListener("close", () => {
    wsConnected = false;
    syncSocket = null;
    notifySyncListeners();
    scheduleWebSocketReconnect();
  });

  syncSocket.addEventListener("error", (event) => {
    console.error("Sync websocket error", event);
  });
}

/**
 * Process the sync queue
 * Sends pending actions to the backend
 */
export async function processQueue() {
  if (isProcessing) {
    console.log("[Queue] Sync already in progress, skipping...");
    return { processed: 0, failed: 0 };
  }

  if (!navigator.onLine) {
    console.log("[Queue] Offline, skipping sync");
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

    console.log(`[Queue] Processing ${pendingItems.length} sync items...`);

    for (const item of pendingItems) {
      if (item.retries >= MAX_RETRIES) {
        console.error(`[Queue] Max retries reached for item ${item.id}`, item);
        await updateSyncQueueItem(item.id, {
          status: "failed",
          error: "Max retries exceeded",
        });
        failed++;
        continue;
      }

      try {
        console.log(`[Queue] Processing ${item.action} for ${item.data.imdb_id || item.data.name || 'item'}`);

        // Mark as processing
        await updateSyncQueueItem(item.id, { status: "processing" });
        notifySyncListeners();

        // Send to backend
        const result = await api.syncProcessAction(item.action, item.data, item.timestamp);

        if (result.success) {
          // Remove from queue on success
          await removeSyncQueueItem(item.id);
          processed++;
          console.log(`[Queue] ✓ Sync successful for ${item.action}`, {
            lastModified: result.last_modified,
          });

          // Update local movie's lastModified if returned
          if (result.last_modified && item.data.imdb_id) {
            await updateLocalMovieTimestamp(item.data.imdb_id, result.last_modified);
            console.log(`[Queue] Updated local timestamp for ${item.data.imdb_id} to ${result.last_modified}`);
          }
        } else if (result.conflict && result.server_state) {
          console.warn(
            `[Queue] Conflict while syncing ${item.action} for ${item.data.imdb_id}, applying server state`,
          );
          await removeSyncQueueItem(item.id);
          await upsertMovieFromServer(result.server_state);
        } else {
          // Increment retries on failure
          await updateSyncQueueItem(item.id, {
            status: "failed",
            retries: item.retries + 1,
            error: result.error || "Unknown error",
          });
          failed++;
          console.error(`[Queue] ✗ Sync failed for ${item.action}:`, result.error);
        }
      } catch (error) {
        console.error(`[Queue] Error processing sync item ${item.id}:`, error);
        await updateSyncQueueItem(item.id, {
          status: "failed",
          retries: item.retries + 1,
          error: error.message,
        });
        failed++;
      }
    }

    console.log(`[Queue] Finished processing: ${processed} succeeded, ${failed} failed`);
  } catch (error) {
    console.error("[Queue] Error processing sync queue:", error);
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
    console.log("[Sync] Offline, skipping server sync");
    return { synced: 0, offline: true };
  }

  if (isSyncingFromServer) {
    console.log("[Sync] Already syncing from server, skipping...");
    return { synced: 0, skipped: true };
  }

  isSyncingFromServer = true;
  notifySyncListeners();

  try {
    const lastSync = await getLastSync();
    const lastSyncSeconds = lastSync ? lastSync / 1000 : 0;

    console.log("[Sync] Syncing from server since:", new Date(lastSync || 0).toISOString(), `(${lastSyncSeconds}s)`);

    const response = await api.syncGetChanges(lastSyncSeconds);

    if (!response) {
      console.warn("[Sync] No response from server");
      return { synced: 0, error: "No response from server" };
    }

    console.log("[Sync] Server response:", {
      movieCount: response.movies?.length || 0,
      peopleCount: response.people?.length || 0,
      timestamp: response.timestamp,
    });

    if (response.people) {
      console.log(`[Sync] Merging ${response.people.length} people from server`);
      await mergePeopleFromServer(response.people);
    }

    let updatedCount = 0;
    if (response.movies && response.movies.length > 0) {
      console.log(`[Sync] Received ${response.movies.length} movies from server`);

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
          const movieData = transformServerMovie(serverMovie);
          await saveMovie(movieData, { preserveTimestamp: true });
          updatedCount++;
          console.log(`[Sync] ✓ Updated movie: ${imdbId}`);
        } else {
          console.log(`[Sync] → Skipped movie ${imdbId} (local is newer)`);
        }
      }
    }

    // Always update last sync timestamp
    if (response.timestamp) {
      await setLastSync(response.timestamp * 1000);
      console.log(`[Sync] Updated lastSync to:`, new Date(response.timestamp * 1000).toISOString());
    } else {
      console.warn("[Sync] No timestamp in response, lastSync not updated");
    }

    const syncedCount = response.movies?.length || 0;
    console.log(`[Sync] Complete: ${updatedCount} movies updated out of ${syncedCount} received`);
    return { synced: syncedCount, updated: updatedCount };
  } catch (error) {
    console.error("[Sync] Error syncing from server:", error);
    // Don't update lastSync on error - we'll retry from the same point
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
 * Syncs on changes (via WebSocket) with a fallback interval for when WebSocket is down
 */
export function startAutoSync() {
  if (syncInterval) {
    console.log("[AutoSync] Already running");
    return;
  }

  console.log("[AutoSync] Starting...");

  // Run immediately (but don't await to avoid blocking)
  fullSync().then(() => {
    console.log("[AutoSync] Initial sync completed");
  }).catch((error) => {
    console.error("[AutoSync] Initial sync failed:", error);
  });

  ensureWebSocketConnection();

  // Longer fallback interval (5 minutes) in case WebSocket is down
  // WebSocket notifications will trigger syncs when changes happen
  syncInterval = setInterval(() => {
    console.log("[AutoSync] Fallback interval sync");
    fullSync();
  }, 300000); // 5 minutes

  // Run when coming online
  const handleOnline = () => {
    console.log("Back online, triggering sync...");
    fullSync();
    ensureWebSocketConnection();
  };

  const handleOffline = () => {
    console.log("Went offline");
    teardownWebSocket();
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
    window.removeEventListener("sw-sync-requested", handleSWSync);
    teardownWebSocket();
  };
}

/**
 * Stop automatic sync
 */
export function stopAutoSync() {
  if (syncInterval) {
    clearInterval(syncInterval);
    syncInterval = null;
    console.log("[AutoSync] Stopped");
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
  const lastSync = await getLastSync();
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
    pendingCount: pending,
    failedCount: failed,
    isOnline,
    isProcessing,
    isSyncingFromServer,
    isRealtimeConnected: wsConnected,
    queueItems: queue,
    lastSync,
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
