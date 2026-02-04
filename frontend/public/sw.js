/**
 * Service Worker for PWA functionality
 * Handles caching and offline support
 */

const CACHE_VERSION = "v2";
const STATIC_CACHE = `movie-tracker-static-${CACHE_VERSION}`;
const RUNTIME_CACHE = `movie-tracker-runtime-${CACHE_VERSION}`;
const IMAGE_CACHE = `movie-tracker-images-${CACHE_VERSION}`;

// Max age for cached API responses (5 minutes)
const API_CACHE_MAX_AGE = 5 * 60 * 1000;

// Max images to cache
const MAX_CACHED_IMAGES = 200;

// Assets to cache on install
const STATIC_ASSETS = ["/", "/index.html", "/manifest.json"];

// Install event - cache static assets
self.addEventListener("install", (event) => {
  console.log("[SW] Installing...");
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      console.log("[SW] Caching static assets");
      return cache.addAll(STATIC_ASSETS);
    }),
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener("activate", (event) => {
  console.log("[SW] Activating...");
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => {
            // Keep only current version caches
            return name.startsWith("movie-tracker-") && !name.includes(CACHE_VERSION);
          })
          .map((name) => {
            console.log("[SW] Deleting old cache:", name);
            return caches.delete(name);
          }),
      );
    }),
  );
  self.clients.claim();
});

// Fetch event handler
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-http(s) requests
  if (!url.protocol.startsWith("http")) {
    return;
  }

  // Skip cross-origin requests except for images
  const isSameOrigin = url.origin === self.location.origin;
  const isImage = request.destination === "image";
  const isExternalImage = !isSameOrigin && isImage;

  // Handle API requests - stale-while-revalidate
  if (url.pathname.startsWith("/api/")) {
    event.respondWith(handleAPIRequest(request));
    return;
  }

  // Handle images - cache first with limit
  if (isImage || isExternalImage) {
    event.respondWith(handleImageRequest(request));
    return;
  }

  // Handle navigation requests - network first, cache fallback
  if (request.mode === "navigate") {
    event.respondWith(handleNavigationRequest(request));
    return;
  }

  // All other same-origin requests - network first
  if (isSameOrigin) {
    event.respondWith(handleStaticRequest(request));
    return;
  }
});

// API request handler - network first with cache fallback
async function handleAPIRequest(request) {
  try {
    const response = await fetch(request);

    if (response.ok) {
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.log("[SW] Network failed for API, trying cache:", request.url);
    const cachedResponse = await caches.match(request);

    if (cachedResponse) {
      return cachedResponse;
    }

    // Return offline response for sync endpoints
    if (request.url.includes("/api/sync")) {
      return new Response(JSON.stringify({ offline: true, error: "You are offline" }), {
        status: 503,
        headers: { "Content-Type": "application/json" },
      });
    }

    throw error;
  }
}

// Image request handler - cache first with LRU
async function handleImageRequest(request) {
  const cachedResponse = await caches.match(request);

  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const response = await fetch(request);

    if (response.ok) {
      const cache = await caches.open(IMAGE_CACHE);

      // Limit cache size
      const keys = await cache.keys();
      if (keys.length >= MAX_CACHED_IMAGES) {
        // Remove oldest entries
        const toDelete = keys.slice(0, 20);
        await Promise.all(toDelete.map((key) => cache.delete(key)));
      }

      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.log("[SW] Image fetch failed:", request.url);
    // Return a placeholder or empty response
    return new Response("", { status: 404 });
  }
}

// Navigation request handler - network first, cache index.html as fallback
async function handleNavigationRequest(request) {
  try {
    const response = await fetch(request);

    if (response.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.log("[SW] Navigation failed, serving cached index.html");
    const cachedResponse = await caches.match("/index.html");
    return cachedResponse || new Response("Offline", { status: 503 });
  }
}

// Static asset handler - network first with cache fallback
async function handleStaticRequest(request) {
  try {
    const response = await fetch(request);

    if (response.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    const cachedResponse = await caches.match(request);
    return cachedResponse || new Response("Offline", { status: 503 });
  }
}

// Background sync for queued actions
self.addEventListener("sync", (event) => {
  console.log("[SW] Background sync triggered:", event.tag);

  if (event.tag === "sync-queue") {
    event.waitUntil(
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({ type: "SYNC_REQUESTED" });
        });
      }),
    );
  }
});

// Handle messages from the app
self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }

  if (event.data && event.data.type === "CLEAR_CACHE") {
    caches.keys().then((names) => {
      names.forEach((name) => caches.delete(name));
    });
  }
});
