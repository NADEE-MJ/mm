/**
 * IndexedDB storage service using idb library
 * Stores movies, sync queue, metadata, and people
 */

import { openDB } from 'idb';

const DB_NAME = 'movieRecommendations';
const DB_VERSION = 1;

// Initialize IndexedDB
export async function initDB() {
  return openDB(DB_NAME, DB_VERSION, {
    upgrade(db) {
      // Movies store
      if (!db.objectStoreNames.contains('movies')) {
        db.createObjectStore('movies', { keyPath: 'imdbId' });
      }

      // Sync queue store
      if (!db.objectStoreNames.contains('syncQueue')) {
        db.createObjectStore('syncQueue', { keyPath: 'id', autoIncrement: true });
      }

      // Metadata store (for lastSync timestamp, etc.)
      if (!db.objectStoreNames.contains('metadata')) {
        db.createObjectStore('metadata', { keyPath: 'key' });
      }

      // People store
      if (!db.objectStoreNames.contains('people')) {
        db.createObjectStore('people', { keyPath: 'name' });
      }
    },
  });
}

// Movies operations
export async function getMovie(imdbId) {
  const db = await initDB();
  return db.get('movies', imdbId);
}

export async function getAllMovies() {
  const db = await initDB();
  return db.getAll('movies');
}

export async function saveMovie(movie, options = {}) {
  const db = await initDB();
  const preserveTimestamp = options.preserveTimestamp || false;
  if (!preserveTimestamp || !movie.lastModified) {
    movie.lastModified = Date.now();
  }
  return db.put('movies', movie);
}

export async function deleteMovie(imdbId) {
  const db = await initDB();
  return db.delete('movies', imdbId);
}

// Sync queue operations
export async function addToSyncQueue(action, data) {
  const db = await initDB();
  const queueItem = {
    action,
    data,
    timestamp: Date.now(),
    retries: 0,
    status: 'pending',
    error: null,
  };
  return db.add('syncQueue', queueItem);
}

export async function getSyncQueue() {
  const db = await initDB();
  return db.getAll('syncQueue');
}

export async function updateSyncQueueItem(id, updates) {
  const db = await initDB();
  const item = await db.get('syncQueue', id);
  if (item) {
    Object.assign(item, updates);
    return db.put('syncQueue', item);
  }
}

export async function removeSyncQueueItem(id) {
  const db = await initDB();
  return db.delete('syncQueue', id);
}

// Metadata operations
export async function getMetadata(key) {
  const db = await initDB();
  const result = await db.get('metadata', key);
  return result ? result.value : null;
}

export async function setMetadata(key, value) {
  const db = await initDB();
  return db.put('metadata', { key, value });
}

export async function getLastSync() {
  return getMetadata('lastSync') || 0;
}

export async function setLastSync(timestamp) {
  return setMetadata('lastSync', timestamp);
}

// People operations
export async function getPerson(name) {
  const db = await initDB();
  return db.get('people', name);
}

export async function getAllPeople() {
  const db = await initDB();
  return db.getAll('people');
}

export async function savePerson(person) {
  const db = await initDB();
  return db.put('people', person);
}

export async function deletePerson(name) {
  const db = await initDB();
  return db.delete('people', name);
}

// Clear all data (useful for testing)
export async function clearAllData() {
  const db = await initDB();
  await db.clear('movies');
  await db.clear('syncQueue');
  await db.clear('metadata');
  await db.clear('people');
}
