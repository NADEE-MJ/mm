# Restore Local-First Functionality to Mobile Swift App

## Context

The Movie Manager mobile Swift app was designed as a local-first application, but this core functionality has degraded over time. Currently:

1. **Users are forced to login when opening the app offline** - Even with valid cached credentials, the app logs out if the token verification network call fails
2. **All data is fetched from the API on every access** - The SQLite database exists with caching infrastructure but is never used
3. **No offline write capability** - Users cannot add or update movies when offline

This implementation restores the local-first architecture, enabling:
- Seamless offline access with cached credentials
- Instant UI responsiveness by reading from local database first
- Offline write operations with automatic sync when connection is restored

## Problems Identified

### Problem 1: Forced Logout When Offline

**Location**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/AuthManager.swift:245-253`

When the app launches, `verifyToken()` calls the `/auth/me` endpoint. If this fails due to **network errors** (no internet), it calls `logout()` which clears the Keychain and forces re-login. This happens even though the user has valid credentials stored locally.

The `fetchMe()` method (lines 271-313) returns `nil` for both network errors (URLError) and actual authentication errors (401/403), making it impossible to distinguish between "offline" and "invalid token".

### Problem 2: No Local-First Data Access

**Locations**:
- `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/HomePageView.swift`
- `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/PeoplePageView.swift`
- `/home/nadeem/Documents/random/mm/mobile/Sources/Services/NetworkService.swift`

All views call `NetworkService` directly, which makes API calls on every access. The `DatabaseManager` has `cacheMovie()` and `cachePerson()` methods but they are **never called**. Data flow is:

```
Views → NetworkService → API → Memory (NetworkService.movies/people)
                                ↓
                          (Never cached to database)
```

Should be:

```
Views → Repository → SQLite (Read First) → UI Update
                   ↓
           Background Sync → API → Cache to SQLite
```

### Problem 3: No Offline Write Capability

When users try to add or update movies/people while offline, the operation fails with no queuing or retry mechanism. Operations are not persisted locally for later sync.

## Solution Overview

### 1. Offline Authentication
Modify `AuthManager` to differentiate between network errors and authentication errors. Allow offline access when token and user exist in Keychain, only logout on actual auth failures (401/403).

### 2. Repository Pattern for Local-First Data Access
Create a `MovieRepository` layer that:
- Reads from SQLite database first for instant display
- Syncs with API in background to get latest data
- Caches all API responses to database
- Manages the full data lifecycle

### 3. Offline Write Queue with Enrichment System
Implement pending operations queue for offline writes:
- **Regular updates** (status, rating): Queue and sync when online
- **Add movie offline**: Allow adding movie with just a name/title as a "draft" or "pending" entry. When online, enrich it by calling TMDB API to get full details and IMDB ID
- Automatic sync when connection is restored
- Retry logic with max attempts

### 4. Enhanced Database Schema
Update `CachedMovie` to store full movie data including:
- All Movie fields (imdbId, genres, director, overview, etc.)
- JSON blob for complete reconstruction
- Add `PendingOperation` table for offline write queue
- Add `PendingMovie` table for movies added offline that need enrichment

## Implementation Plan

### Phase 1: Fix Offline Authentication (Critical)

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/AuthManager.swift`

**Step 1.1**: Add `AuthVerificationResult` enum after line 323:
```swift
enum AuthVerificationResult {
    case success(AuthUser)
    case networkError(String)
    case authError(String)
}
```

**Step 1.2**: Replace `fetchMe(token:)` method (lines 271-313) to return `AuthVerificationResult`:
- Catch `URLError` separately and return `.networkError`
- Check HTTP status codes: 401/403 returns `.authError`
- Successful decode returns `.success(user)`

**Step 1.3**: Update `verifyToken()` (lines 245-253) to handle results:
```swift
func verifyToken() async {
    guard let token else { return }
    let result = await fetchMe(token: token)

    switch result {
    case .success(let fetchedUser):
        user = fetchedUser  // Update user info
    case .networkError:
        // Keep existing auth, allow offline mode
        // DON'T call logout()
    case .authError:
        logout()  // Only logout for actual auth errors
    }
}
```

**Step 1.4**: Update `login()` method (line 120) to use new result type

### Phase 2: Enhanced Database Schema

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/DatabaseManager.swift`

**Step 2.1**: Add `imdbId` and `jsonData` columns to `CachedMovie` struct (lines 19-36):
```swift
struct CachedMovie: Identifiable, Hashable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "movies"

    let id: Int
    let tmdbId: Int
    let imdbId: String
    let title: String
    let posterPath: String?
    let status: String
    let myRating: Int?
    let dateWatched: String?
    let cachedAt: Date
    let jsonData: String  // Full Movie JSON for reconstruction

    // Add conversion methods
    func toMovie() -> Movie? { ... }
    static func from(_ movie: Movie) -> CachedMovie? { ... }
}
```

**Step 2.2**: Add `PendingOperation` table struct after `CachedPerson` (line 52):
```swift
struct PendingOperation: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pending_operations"

    let id: String  // UUID
    let type: String  // "add_movie", "update_movie", etc.
    let payload: String  // JSON payload
    let createdAt: Date
    let retryCount: Int
}
```

**Step 2.3**: Add `PendingMovie` table for offline movie additions:
```swift
struct PendingMovie: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pending_movies"

    let id: String  // UUID
    let title: String  // User-provided title
    let recommender: String
    let createdAt: Date
    let needsEnrichment: Bool  // true if added offline
}
```

**Step 2.4**: Update migrations (after line 96):
```swift
migrator.registerMigration("v2_full_movie_cache") { db in
    // Add new columns to movies table
    try db.alter(table: "movies") { t in
        t.add(column: "imdb_id", .text).defaults(to: "")
        t.add(column: "json_data", .text)
    }

    // Clear existing incomplete cache (will rebuild from API)
    try db.execute(sql: "DELETE FROM movies")
}

migrator.registerMigration("v2_pending_operations") { db in
    try db.create(table: "pending_operations") { t in
        t.column("id", .text).primaryKey()
        t.column("type", .text).notNull()
        t.column("payload", .text).notNull()
        t.column("created_at", .double).notNull()
        t.column("retry_count", .integer).notNull().defaults(to: 0)
    }
}

migrator.registerMigration("v2_pending_movies") { db in
    try db.create(table: "pending_movies") { t in
        t.column("id", .text).primaryKey()
        t.column("title", .text).notNull()
        t.column("recommender", .text).notNull()
        t.column("created_at", .double).notNull()
        t.column("needs_enrichment", .boolean).notNull().defaults(to: true)
    }
}
```

**Step 2.5**: Add batch caching and queue methods to `DatabaseManager` (after line 162):
```swift
// Batch operations for sync
func cacheMovies(_ movies: [Movie]) { ... }
func cachePeople(_ people: [Person]) { ... }

// Pending operations queue
func enqueuePendingOperation(type: String, payload: String) { ... }
func fetchPendingOperations() -> [PendingOperation] { ... }
func deletePendingOperation(id: String) { ... }
func incrementRetryCount(id: String) { ... }

// Pending movies (offline additions)
func addPendingMovie(title: String, recommender: String) -> String { ... }
func fetchPendingMovies() -> [PendingMovie] { ... }
func deletePendingMovie(id: String) { ... }
```

### Phase 3: Repository Layer for Local-First Access

**New File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/Repository.swift`

Create `DataRepository` protocol defining the contract for local-first data access:
```swift
protocol DataRepository {
    func getMovies(status: String?) async -> Result<[Movie], RepositoryError>
    func getPeople() async -> Result<[Person], RepositoryError>
    func addMovie(tmdbId: Int, recommender: String) async -> Result<Movie, RepositoryError>
    func updateMovie(movie: Movie, rating: Int?, status: String?) async -> Result<Movie, RepositoryError>
    func syncNow() async
    var isSyncing: Bool { get }
}

enum RepositoryError: Error {
    case networkError(String)
    case databaseError(String)
    case notFound(String)
}
```

**New File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/MovieRepository.swift`

Implement the repository pattern:

```swift
@MainActor
@Observable
final class MovieRepository: DataRepository {
    static let shared = MovieRepository()

    private let networkService = NetworkService.shared
    private let databaseManager = DatabaseManager.shared

    private(set) var movies: [Movie] = []
    private(set) var people: [Person] = []
    private(set) var isSyncing = false
    private(set) var lastSyncTime: Date?

    func getMovies(status: String? = nil) async -> Result<[Movie], RepositoryError> {
        // 1. Read from database first (instant display)
        let cachedMovies = databaseManager.cachedMovies
            .compactMap { $0.toMovie() }

        if !cachedMovies.isEmpty {
            movies = cachedMovies
            // Show cached data immediately

            // 2. Sync in background to get updates
            Task { await syncMovies() }

            return .success(filterMovies(movies, status: status))
        }

        // No cache - fetch from network
        await syncMovies()
        return .success(filterMovies(movies, status: status))
    }

    func addMovie(tmdbId: Int, recommender: String) async -> Result<Movie, RepositoryError> {
        let success = await networkService.addMovie(tmdbId: tmdbId, recommender: recommender)

        if success {
            await syncMovies()
            // Find newly added movie
            if let movie = movies.first(where: { $0.tmdbId == tmdbId }) {
                return .success(movie)
            }
        } else if isNetworkError() {
            // Queue for later sync
            let payload = encodeAddMoviePayload(tmdbId: tmdbId, recommender: recommender)
            databaseManager.enqueuePendingOperation(type: "add_movie", payload: payload)
            return .failure(.networkError("Queued for sync when online"))
        }

        return .failure(.networkError(networkService.lastError ?? "Unknown error"))
    }

    private func syncMovies() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        await networkService.fetchMovies()

        if networkService.lastError == nil {
            // Cache to database
            databaseManager.cacheMovies(networkService.movies)
            movies = networkService.movies
            lastSyncTime = .now
        }
    }

    // Similar methods for people, updates, etc.
}
```

### Phase 4: Offline Write Queue & Sync Manager

**New File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/SyncManager.swift`

Create sync manager to process pending operations:

```swift
@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    private let databaseManager = DatabaseManager.shared
    private let networkService = NetworkService.shared

    private(set) var isSyncing = false
    private(set) var pendingCount = 0

    func processPendingOperations() async {
        let operations = databaseManager.fetchPendingOperations()

        for operation in operations {
            let success = await processOperation(operation)

            if success {
                databaseManager.deletePendingOperation(id: operation.id)
            } else {
                if operation.retryCount >= 3 {
                    // Max retries - delete
                    databaseManager.deletePendingOperation(id: operation.id)
                } else {
                    databaseManager.incrementRetryCount(id: operation.id)
                }
            }
        }

        updatePendingCount()
    }

    func enrichPendingMovies() async {
        // Process movies added offline that need TMDB enrichment
        let pendingMovies = databaseManager.fetchPendingMovies()

        for pending in pendingMovies {
            // 1. Search TMDB for the title
            let results = await networkService.searchMovies(query: pending.title)

            if let match = results.first {
                // 2. Add the movie with proper TMDB ID
                let success = await networkService.addMovie(
                    tmdbId: match.id,
                    recommender: pending.recommender
                )

                if success {
                    databaseManager.deletePendingMovie(id: pending.id)
                }
            }
        }
    }
}
```

### Phase 5: Update Views to Use Repository

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/HomePageView.swift`

Replace direct `NetworkService` calls with `MovieRepository`:

**Lines 269-274** - Update `loadAllMovies()`:
```swift
private func loadAllMovies() async {
    isLoading = true
    let result = await MovieRepository.shared.getMovies()
    switch result {
    case .success(let movies):
        allMovies = movies
    case .failure(let error):
        // Show error but keep cached data
        print("Error: \(error)")
    }
    isLoading = false
}
```

**Lines 128-134, 143-149, etc.** - Replace all `NetworkService.shared.updateMovie(...)` with:
```swift
_ = await MovieRepository.shared.updateMovie(...)
```

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/PeoplePageView.swift`

Similar updates for people operations.

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/AddMoviePageView.swift` (if exists)

Update to support offline movie additions:
- Allow adding movie with just a name when offline
- Show indicator that it will be enriched when online
- Store in `PendingMovie` table

### Phase 6: Integrate Sync Triggers

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/MobileSwiftApp.swift`

Add sync triggers when app becomes active (already has WebSocket reconnect logic):

**After line 45** - Update `.onChange(of: scenePhase)`:
```swift
.onChange(of: scenePhase) { _, newPhase in
    guard newPhase == .active else { return }

    // Process pending operations when app becomes active
    Task {
        await SyncManager.shared.processPendingOperations()
        await SyncManager.shared.enrichPendingMovies()
    }

    updateWebSocketConnection(reason: "scene-active")
}
```

### Phase 7: Initial Data Sync & Migration

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Services/MovieRepository.swift`

Add method to detect first launch after update and trigger full sync:

```swift
func performInitialSyncIfNeeded() async {
    let hasPerformedInitialSync = UserDefaults.standard.bool(forKey: "has_performed_v2_sync")

    if !hasPerformedInitialSync {
        // First launch after update - clear old cache and rebuild
        databaseManager.clearAll()
        await syncMovies()
        await syncPeople()
        UserDefaults.standard.set(true, forKey: "has_performed_v2_sync")
    }
}
```

Call this from `MobileSwiftApp.swift` in the `.task` block after `verifyToken()`.

### Phase 8: Image Caching for Movie Posters

**Problem**: Movie poster images are re-downloaded every time they're displayed, wasting bandwidth and causing slow load times.

**Solution**: Configure persistent URLCache for image caching and create a custom AsyncImage wrapper for better control.

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/MobileSwiftApp.swift`

**Step 8.1**: Configure URLCache with custom cache policy in app initialization:

Add at the start of `MobileSwiftApp` body or in an `init()`:
```swift
init() {
    configureImageCache()
}

private func configureImageCache() {
    // Configure persistent image cache (100MB memory, 500MB disk)
    let cache = URLCache(
        memoryCapacity: 100 * 1024 * 1024,  // 100 MB memory
        diskCapacity: 500 * 1024 * 1024,     // 500 MB disk
        diskPath: "movie_images"
    )
    URLCache.shared = cache

    // Configure URLSession with custom cache policy
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .returnCacheDataElseLoad  // Use cache when available
    config.urlCache = cache
}
```

**Cache Expiration Strategy**:
- Images are cached with a **90-day expiration** (set via HTTP cache headers when storing)
- When cache reaches 500MB limit, oldest images are automatically evicted (LRU)
- Movie posters rarely change, so 90 days is a good balance
- Manual clear option available in Settings

**New File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Components/CachedAsyncImage.swift`

Create a reusable cached image component:
```swift
import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var cachedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url else { return }

        isLoading = true
        defer { isLoading = false }

        // Check URLCache first
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            cachedImage = image
            return
        }

        // Download if not cached
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Cache the response with 90-day expiration
            if let httpResponse = response as? HTTPURLResponse {
                // Create modified response with cache headers
                var headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
                headers["Cache-Control"] = "max-age=7776000"  // 90 days in seconds

                if let modifiedResponse = HTTPURLResponse(
                    url: httpResponse.url!,
                    statusCode: httpResponse.statusCode,
                    httpVersion: nil,
                    headerFields: headers
                ) {
                    let cachedData = CachedURLResponse(response: modifiedResponse, data: data)
                    URLCache.shared.storeCachedResponse(cachedData, for: request)
                }
            }

            if let image = UIImage(data: data) {
                cachedImage = image
            }
        } catch {
            AppLog.warning("Failed to load image: \(error.localizedDescription)", category: .network)
        }
    }
}

// Convenience initializer matching AsyncImage API
extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0.resizable() },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
```

**Step 8.2**: Replace `AsyncImage` with `CachedAsyncImage` in views:

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/HomePageView.swift`

Find all `AsyncImage` usages and replace with `CachedAsyncImage`:
```swift
// Before
AsyncImage(url: movie.posterURL) { image in
    image.resizable().aspectRatio(contentMode: .fill)
} placeholder: {
    Color.gray.opacity(0.2)
}

// After
CachedAsyncImage(url: movie.posterURL) { image in
    image.resizable().aspectRatio(contentMode: .fill)
} placeholder: {
    Color.gray.opacity(0.2)
}
```

Apply similar changes to:
- `/home/nadeem/Documents/random/mm/mobile/Sources/Views/GlobalSearchPageView.swift`
- `/home/nadeem/Documents/random/mm/mobile/Sources/Views/AddMoviePageView.swift`
- Any other views displaying movie posters

**Step 8.3**: Add cache management to Settings (optional):

**File**: `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/AccountPageView.swift`

Add button to clear image cache:
```swift
Button("Clear Image Cache") {
    URLCache.shared.removeAllCachedResponses()
}
```

**Benefits**:
- Images cached for 90 days (posters rarely change)
- 500MB disk cache holds ~500-1000 posters
- Instant loading for previously viewed posters
- Automatic eviction of oldest images when cache is full (LRU)
- Works offline automatically
- Reduces bandwidth usage by 90%+ for repeat views
- Manual clear option in Settings

## Critical Files

### Files to Modify:
1. `/home/nadeem/Documents/random/mm/mobile/Sources/Services/AuthManager.swift` - Fix offline auth
2. `/home/nadeem/Documents/random/mm/mobile/Sources/Services/DatabaseManager.swift` - Enhanced schema and queue methods
3. `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/HomePageView.swift` - Use repository + cached images
4. `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/PeoplePageView.swift` - Use repository
5. `/home/nadeem/Documents/random/mm/mobile/Sources/MobileSwiftApp.swift` - Add sync triggers + URLCache config
6. `/home/nadeem/Documents/random/mm/mobile/Sources/Views/GlobalSearchPageView.swift` - Use cached images
7. `/home/nadeem/Documents/random/mm/mobile/Sources/Views/AddMoviePageView.swift` - Use cached images
8. `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Tabs/AccountPageView.swift` - Add cache clear option (optional)

### Files to Create:
1. `/home/nadeem/Documents/random/mm/mobile/Sources/Services/Repository.swift` - Protocol definition
2. `/home/nadeem/Documents/random/mm/mobile/Sources/Services/MovieRepository.swift` - Repository implementation
3. `/home/nadeem/Documents/random/mm/mobile/Sources/Services/SyncManager.swift` - Sync orchestration
4. `/home/nadeem/Documents/random/mm/mobile/Sources/Views/Components/CachedAsyncImage.swift` - Image caching component

### Existing Files Referenced (Read Only):
- `/home/nadeem/Documents/random/mm/mobile/Sources/Services/NetworkService.swift` - Movie/Person structs and API calls
- `/home/nadeem/Documents/random/mm/mobile/Sources/Services/AppConfiguration.swift` - API URL config
- `/home/nadeem/Documents/random/mm/mobile/Sources/Views/RootTabHostView.swift` - Main navigation

## Testing Plan

### Test 1: Offline Launch with Valid Credentials
1. Launch app with internet, login successfully
2. Turn on airplane mode
3. Force quit app
4. Relaunch app
5. **Expected**: App opens to movie list with cached data, no login screen

### Test 2: Offline Data Access
1. Launch app with internet
2. View movies (loads and caches from API)
3. Turn on airplane mode
4. Pull to refresh
5. **Expected**: Shows cached data immediately, indicates offline mode

### Test 3: Offline Movie Update (Queue)
1. Launch app online
2. Turn on airplane mode
3. Update movie status (e.g., mark as watched)
4. **Expected**: Operation queued, UI shows pending indicator
5. Turn internet back on
6. **Expected**: Queued operation syncs automatically

### Test 4: Offline Movie Addition (Enrichment)
1. Launch app online
2. Turn on airplane mode
3. Try to add a movie (enter title only)
4. **Expected**: Movie saved as "pending enrichment"
5. Turn internet back on
6. **Expected**: App searches TMDB for title, adds movie with full details

### Test 5: Network Error vs Auth Error
1. Valid cached credentials + airplane mode
2. **Expected**: App stays logged in
3. Manually corrupt token in Keychain
4. **Expected**: App logs out on next verification

### Test 6: First Sync After Update
1. Existing user with old database
2. Update to new version
3. **Expected**: Old cache cleared, full sync from API on first launch

### Test 7: Image Caching
1. Launch app online, view movie list
2. **Expected**: Posters download and display
3. Turn on airplane mode
4. Navigate away and back to movie list
5. **Expected**: Posters load instantly from cache
6. Check Settings
7. **Expected**: "Clear Image Cache" button available

## Verification Steps

After implementation, verify:

1. **Authentication**:
   - [ ] Can open app offline with cached credentials
   - [ ] Invalid token causes logout
   - [ ] Network error during verify does NOT cause logout

2. **Data Access**:
   - [ ] Movies/people load instantly from database
   - [ ] Background sync updates cache
   - [ ] Pull to refresh works offline (shows cached data)

3. **Offline Writes**:
   - [ ] Update operations queue when offline
   - [ ] Add movie operations create pending entries
   - [ ] Pending operations sync when online

4. **Database**:
   - [ ] Check SQLite file has data after first sync
   - [ ] Verify pending_operations table exists
   - [ ] Verify pending_movies table exists

5. **Migration**:
   - [ ] First launch clears old cache
   - [ ] UserDefaults flag prevents repeated clears

6. **Image Caching**:
   - [ ] Posters cached to disk after first load
   - [ ] Cached images load instantly on repeat views
   - [ ] Cache persists across app launches
   - [ ] Works offline automatically
   - [ ] Clear cache button functions properly

## Implementation Notes

- All async operations use Swift concurrency (async/await)
- Use GRDB transactions for database writes
- Repository pattern maintains separation of concerns
- Observable properties for SwiftUI automatic updates
- Comprehensive logging for debugging (AppLog)
- Error handling preserves cached data on network failures
