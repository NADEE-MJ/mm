import Foundation

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

    private let firstSyncKey = "has_performed_v2_sync"
    private let backgroundSyncInterval: TimeInterval = 90
    private var lastMoviesSyncAt: Date?
    private var lastPeopleSyncAt: Date?
    private var isSyncingMovies = false
    private var isSyncingPeople = false

    private init() {
        loadFromCache()
    }

    func getMovies(status: String? = nil) async -> Result<[Movie], RepositoryError> {
        loadFromCache()

        if !movies.isEmpty {
            let filtered = filterMovies(movies, status: status)
            Task { await syncMovies(force: false) }
            return .success(filtered)
        }

        let synced = await syncMovies(force: true)
        if !synced, let error = networkService.lastError {
            return .failure(.networkError(error))
        }

        return .success(filterMovies(movies, status: status))
    }

    func getPeople() async -> Result<[Person], RepositoryError> {
        loadFromCache()

        if !people.isEmpty {
            Task { await syncPeople(force: false) }
            return .success(people)
        }

        let synced = await syncPeople(force: true)
        if !synced, let error = networkService.lastError {
            return .failure(.networkError(error))
        }

        return .success(people)
    }

    func getPersonMovies(personName: String) async -> Result<[Movie], RepositoryError> {
        loadFromCache()

        if movies.isEmpty {
            _ = await getMovies(status: nil)
        }

        let localMatches = movies.filter { movie in
            movie.recommendations.contains { rec in
                rec.recommender.caseInsensitiveCompare(personName) == .orderedSame
            }
        }

        if !localMatches.isEmpty {
            Task { await syncMovies(force: false) }
            return .success(localMatches)
        }

        let remoteMatches = await networkService.fetchPersonMovies(personName: personName)
        if !remoteMatches.isEmpty {
            mergeMovies(remoteMatches)
            return .success(remoteMatches)
        }

        if let error = networkService.lastError {
            return .failure(.networkError(error))
        }

        return .success([])
    }

    func addMovie(tmdbId: Int, recommender: String) async -> Result<Movie, RepositoryError> {
        let trimmedRecommender = recommender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecommender.isEmpty else {
            return .failure(.notFound("Recommender is required"))
        }

        let success = await networkService.addMovie(tmdbId: tmdbId, recommender: trimmedRecommender)
        if success {
            _ = await syncMovies()

            if let movie = movies.first(where: { $0.tmdbId == tmdbId || $0.id == tmdbId }) {
                return .success(movie)
            }

            return .failure(.notFound("Movie was added but could not be found in local cache"))
        }

        let message = networkService.lastError ?? "Unknown network error"
        if isLikelyNetworkError(message) {
            queueOperation(
                type: PendingOperationType.addMovie,
                payload: AddMovieOperationPayload(tmdbId: tmdbId, recommender: trimmedRecommender)
            )
            return .failure(.queued("Queued for sync when connection is restored"))
        }

        return .failure(.networkError(message))
    }

    func addMovieBulk(tmdbId: Int, recommenders: [String]) async -> Result<Void, RepositoryError> {
        let trimmedRecommenders = recommenders
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedRecommenders.isEmpty else {
            return .failure(.notFound("At least one recommender is required"))
        }

        let success = await networkService.addMovieBulk(tmdbId: tmdbId, recommenders: trimmedRecommenders)
        if success {
            _ = await syncMovies()
            return .success(())
        }

        let message = networkService.lastError ?? "Unknown network error"
        if isLikelyNetworkError(message) {
            queueOperation(
                type: PendingOperationType.addMovieBulk,
                payload: AddMovieBulkOperationPayload(tmdbId: tmdbId, recommenders: trimmedRecommenders)
            )
            return .failure(.queued("Queued for sync when connection is restored"))
        }

        return .failure(.networkError(message))
    }

    func addRecommender(movie: Movie, recommender: String) async -> Result<Movie, RepositoryError> {
        await addRecommender(movie: movie, recommender: recommender, voteType: "upvote")
    }

    func addRecommender(movie: Movie, recommender: String, voteType: String) async -> Result<Movie, RepositoryError> {
        let trimmedRecommender = recommender.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedVoteType = voteType.lowercased() == "downvote" ? "downvote" : "upvote"
        guard !trimmedRecommender.isEmpty else {
            return .failure(.notFound("Recommender is required"))
        }
        guard movie.status == "to_watch" else {
            return .failure(.notFound("You can only change recommenders for To Watch movies"))
        }

        if let existing = movie.recommendations.first(where: {
            $0.recommender.caseInsensitiveCompare(trimmedRecommender) == .orderedSame
        }), existing.voteType.lowercased() == normalizedVoteType {
            return .success(movie)
        }

        let nextRecommendations = movie.recommendations
            .filter { $0.recommender.caseInsensitiveCompare(trimmedRecommender) != .orderedSame }
            + [Recommendation(recommender: trimmedRecommender, dateRecommended: isoTimestampNow(), voteType: normalizedVoteType)]

        let previous = movie
        let optimisticMovie = Movie(
            id: movie.id,
            imdbId: movie.imdbId,
            tmdbId: movie.tmdbId,
            title: movie.title,
            posterPath: movie.posterPath,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            voteAverage: movie.voteAverage,
            imdbRating: movie.imdbRating,
            rottenTomatoesRating: movie.rottenTomatoesRating,
            metacriticScore: movie.metacriticScore,
            genres: movie.genres,
            director: movie.director,
            actors: movie.actors,
            status: movie.status,
            myRating: movie.myRating,
            dateWatched: movie.dateWatched,
            recommendations: nextRecommendations
        )
        applyOptimisticMovie(optimisticMovie, requestedStatus: nil)

        let success = await networkService.addRecommendation(
            imdbId: movie.imdbId,
            person: trimmedRecommender,
            voteType: normalizedVoteType
        )
        if success {
            _ = await syncPeople()
            _ = await syncMovies()
            if let updated = movies.first(where: { $0.imdbId == movie.imdbId }) {
                return .success(updated)
            }
            return .success(optimisticMovie)
        }

        let message = networkService.lastError ?? "Unknown network error"
        if isLikelyNetworkError(message) {
            queueOperation(
                type: PendingOperationType.addRecommendation,
                payload: AddRecommendationOperationPayload(
                    imdbId: movie.imdbId,
                    recommender: trimmedRecommender,
                    voteType: normalizedVoteType
                )
            )
            return .failure(.queued("Update queued for sync when connection is restored"))
        }

        restoreMovie(previous)
        return .failure(.networkError(message))
    }

    func removeRecommender(movie: Movie, recommender: String) async -> Result<Movie, RepositoryError> {
        let trimmedRecommender = recommender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecommender.isEmpty else {
            return .failure(.notFound("Recommender is required"))
        }
        guard movie.status == "to_watch" else {
            return .failure(.notFound("You can only change recommenders for To Watch movies"))
        }

        let remainingRecommendations = movie.recommendations.filter {
            $0.recommender.caseInsensitiveCompare(trimmedRecommender) != .orderedSame
        }
        guard remainingRecommendations.count != movie.recommendations.count else {
            return .failure(.notFound("Recommender not found"))
        }

        let previous = movie
        let optimisticMovie = Movie(
            id: movie.id,
            imdbId: movie.imdbId,
            tmdbId: movie.tmdbId,
            title: movie.title,
            posterPath: movie.posterPath,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            voteAverage: movie.voteAverage,
            imdbRating: movie.imdbRating,
            rottenTomatoesRating: movie.rottenTomatoesRating,
            metacriticScore: movie.metacriticScore,
            genres: movie.genres,
            director: movie.director,
            actors: movie.actors,
            status: movie.status,
            myRating: movie.myRating,
            dateWatched: movie.dateWatched,
            recommendations: remainingRecommendations
        )
        applyOptimisticMovie(optimisticMovie, requestedStatus: nil)

        let success = await networkService.removeRecommendation(imdbId: movie.imdbId, person: trimmedRecommender)
        if success {
            _ = await syncPeople()
            _ = await syncMovies()
            if let updated = movies.first(where: { $0.imdbId == movie.imdbId }) {
                return .success(updated)
            }
            return .success(optimisticMovie)
        }

        let message = networkService.lastError ?? "Unknown network error"
        if isLikelyNetworkError(message) {
            queueOperation(
                type: PendingOperationType.removeRecommendation,
                payload: RemoveRecommendationOperationPayload(imdbId: movie.imdbId, recommender: trimmedRecommender)
            )
            return .failure(.queued("Update queued for sync when connection is restored"))
        }

        restoreMovie(previous)
        return .failure(.networkError(message))
    }

    func queueMovieByTitle(title: String, recommender: String) async -> Result<String, RepositoryError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRecommender = recommender.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return .failure(.notFound("Movie title is required"))
        }

        guard !trimmedRecommender.isEmpty else {
            return .failure(.notFound("Recommender is required"))
        }

        let id = databaseManager.addPendingMovie(title: trimmedTitle, recommender: trimmedRecommender)
        return .success(id)
    }

    func fetchPendingMovies() -> [DatabaseManager.PendingMovie] {
        databaseManager.fetchPendingMovies()
    }

    func deletePendingMovie(id: String) {
        databaseManager.deletePendingMovie(id: id)
    }

    func resolvePendingMovie(pendingMovieId: String, tmdbId: Int) async -> Result<Void, RepositoryError> {
        guard let pendingMovie = databaseManager.fetchPendingMovies().first(where: { $0.id == pendingMovieId }) else {
            return .failure(.notFound("Pending movie not found"))
        }

        let addResult = await addMovie(tmdbId: tmdbId, recommender: pendingMovie.recommender)
        switch addResult {
        case .success:
            databaseManager.deletePendingMovie(id: pendingMovieId)
            return .success(())
        case .failure(.queued(let message)):
            // User already chose the exact movie; keep only the concrete queued operation.
            databaseManager.deletePendingMovie(id: pendingMovieId)
            return .failure(.queued(message))
        case .failure(let error):
            return .failure(error)
        }
    }

    func updateMovie(movie: Movie, rating: Int?, status: String?) async -> Result<Movie, RepositoryError> {
        let optimisticMovie = applyingMovieUpdate(movie: movie, rating: rating, status: status)
        applyOptimisticMovie(optimisticMovie, requestedStatus: status)

        await networkService.updateMovie(movie: movie, rating: rating, status: status)

        if networkService.lastError == nil {
            _ = await syncMovies()
            if let updated = movies.first(where: { $0.imdbId == movie.imdbId }) {
                return .success(updated)
            }
            return .success(optimisticMovie)
        }

        let message = networkService.lastError ?? "Unknown network error"
        if isLikelyNetworkError(message) {
            queueOperation(
                type: PendingOperationType.updateMovie,
                payload: UpdateMovieOperationPayload(imdbId: movie.imdbId, rating: rating, status: status)
            )
            return .failure(.queued("Update queued for sync when connection is restored"))
        }

        restoreMovie(movie)
        return .failure(.networkError(message))
    }

    func refreshMovieMetadata(imdbId: String) async -> Result<Movie, RepositoryError> {
        let refreshed = await networkService.refreshMovieMetadata(imdbId: imdbId)
        guard refreshed else {
            let message = networkService.lastError ?? "Unknown network error"
            return .failure(.networkError(message))
        }

        let synced = await syncMovies(force: true)
        guard synced else {
            let message = networkService.lastError ?? "Movie refreshed but failed to sync local data"
            return .failure(.networkError(message))
        }

        guard let movie = movies.first(where: { $0.imdbId == imdbId }) else {
            return .failure(.notFound("Movie refreshed but was not found in local cache"))
        }

        return .success(movie)
    }

    func updatePerson(name: String, isTrusted: Bool) async -> Result<Void, RepositoryError> {
        let previous = people
        applyOptimisticPersonUpdate(name: name, isTrusted: isTrusted)

        await networkService.updatePerson(name: name, isTrusted: isTrusted)

        if networkService.lastError == nil {
            _ = await syncPeople()
            return .success(())
        }

        let message = networkService.lastError ?? "Unknown network error"
        if isLikelyNetworkError(message) {
            queueOperation(
                type: PendingOperationType.updatePerson,
                payload: UpdatePersonOperationPayload(name: name, isTrusted: isTrusted)
            )
            return .failure(.queued("Update queued for sync when connection is restored"))
        }

        people = previous
        databaseManager.cachePeople(people)
        return .failure(.networkError(message))
    }

    func syncNow() async {
        guard !isSyncing else { return }
        guard AuthManager.shared.isAuthenticated else { return }

        isSyncing = true
        defer { isSyncing = false }

        await SyncManager.shared.processPendingOperations()
        await SyncManager.shared.enrichPendingMovies()
        _ = await syncPeople(force: true)
        _ = await syncMovies(force: true)
    }

    func performInitialSyncIfNeeded() async {
        guard AuthManager.shared.isAuthenticated else { return }

        let hasPerformedInitialSync = UserDefaults.standard.bool(forKey: firstSyncKey)
        guard !hasPerformedInitialSync else { return }

        databaseManager.clearAll()
        _ = await syncPeople(force: true)
        _ = await syncMovies(force: true)
        UserDefaults.standard.set(true, forKey: firstSyncKey)
    }

    @discardableResult
    func syncMovies(force: Bool = true) async -> Bool {
        guard AuthManager.shared.isAuthenticated else { return false }
        if !force && !shouldSync(lastSync: lastMoviesSyncAt) { return true }
        guard !isSyncingMovies else { return true }
        isSyncingMovies = true
        defer { isSyncingMovies = false }

        await networkService.fetchMovies()
        guard networkService.lastError == nil else {
            return false
        }

        movies = networkService.movies
        databaseManager.cacheMovies(movies)
        lastSyncTime = .now
        lastMoviesSyncAt = .now
        return true
    }

    @discardableResult
    func syncPeople(force: Bool = true) async -> Bool {
        guard AuthManager.shared.isAuthenticated else { return false }
        if !force && !shouldSync(lastSync: lastPeopleSyncAt) { return true }
        guard !isSyncingPeople else { return true }
        isSyncingPeople = true
        defer { isSyncingPeople = false }

        await networkService.fetchPeople()
        guard networkService.lastError == nil else {
            return false
        }

        people = networkService.people
        databaseManager.cachePeople(people)
        lastSyncTime = .now
        lastPeopleSyncAt = .now
        return true
    }

    private func loadFromCache() {
        databaseManager.loadCache()
        movies = databaseManager.cachedMovies.compactMap { $0.toMovie() }
        people = databaseManager.cachedPeople.map { $0.toPerson() }
    }

    private func mergeMovies(_ incoming: [Movie]) {
        var byImdb = Dictionary(uniqueKeysWithValues: movies.map { ($0.imdbId, $0) })
        for movie in incoming {
            byImdb[movie.imdbId] = movie
        }

        movies = Array(byImdb.values)
        databaseManager.cacheMovies(movies)
    }

    private func filterMovies(_ input: [Movie], status: String?) -> [Movie] {
        guard let status else { return input }
        let normalized = normalizeAppStatus(status)
        return input.filter { normalizeAppStatus($0.status) == normalized }
    }

    private func normalizeAppStatus(_ status: String) -> String {
        switch status {
        case "toWatch", "to_watch":
            return "to_watch"
        default:
            return status
        }
    }

    private func applyingMovieUpdate(movie: Movie, rating: Int?, status: String?) -> Movie {
        let nextStatus = status ?? movie.status
        let nextRating = rating ?? movie.myRating

        let nextDateWatched: String?
        if nextStatus == "watched" {
            nextDateWatched = movie.dateWatched ?? isoTimestampNow()
        } else if nextStatus == "to_watch" {
            nextDateWatched = nil
        } else {
            nextDateWatched = movie.dateWatched
        }

        return Movie(
            id: movie.id,
            imdbId: movie.imdbId,
            tmdbId: movie.tmdbId,
            title: movie.title,
            posterPath: movie.posterPath,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            voteAverage: movie.voteAverage,
            imdbRating: movie.imdbRating,
            rottenTomatoesRating: movie.rottenTomatoesRating,
            metacriticScore: movie.metacriticScore,
            genres: movie.genres,
            director: movie.director,
            actors: movie.actors,
            status: nextStatus,
            myRating: nextRating,
            dateWatched: nextDateWatched,
            recommendations: movie.recommendations
        )
    }

    private func applyOptimisticMovie(_ movie: Movie, requestedStatus: String?) {
        if requestedStatus == "deleted" {
            movies.removeAll { $0.imdbId == movie.imdbId }
        } else if let index = movies.firstIndex(where: { $0.imdbId == movie.imdbId }) {
            movies[index] = movie
        } else {
            movies.append(movie)
        }

        databaseManager.cacheMovies(movies)
    }

    private func restoreMovie(_ movie: Movie) {
        if let index = movies.firstIndex(where: { $0.imdbId == movie.imdbId }) {
            movies[index] = movie
        } else {
            movies.append(movie)
        }
        databaseManager.cacheMovies(movies)
    }

    private func applyOptimisticPersonUpdate(name: String, isTrusted: Bool) {
        if let index = people.firstIndex(where: { $0.name == name }) {
            let existing = people[index]
            people[index] = Person(name: existing.name, isTrusted: isTrusted, movieCount: existing.movieCount)
        }
        databaseManager.cachePeople(people)
    }

    private func queueOperation<T: Encodable>(type: String, payload: T) {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8)
        else {
            AppLog.error("[Repository] Failed to encode pending operation payload for \(type)", category: .database)
            return
        }

        databaseManager.enqueuePendingOperation(type: type, payload: json)
    }

    private func isLikelyNetworkError(_ message: String) -> Bool {
        let text = message.lowercased()
        let markers = [
            "offline",
            "internet",
            "not connected",
            "cannot connect",
            "could not connect",
            "connection",
            "timed out",
            "host",
            "dns",
            "network",
            "socket"
        ]
        return markers.contains { text.contains($0) }
    }

    private func shouldSync(lastSync: Date?) -> Bool {
        guard let lastSync else { return true }
        return Date().timeIntervalSince(lastSync) >= backgroundSyncInterval
    }

    private func isoTimestampNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: .now)
    }
}
