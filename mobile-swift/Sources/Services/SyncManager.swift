import Foundation

@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    private let databaseManager = DatabaseManager.shared
    private let networkService = NetworkService.shared

    private(set) var isSyncing = false
    private(set) var pendingCount = 0

    private init() {
        updatePendingCount()
    }

    func processPendingOperations() async {
        guard !isSyncing else { return }

        isSyncing = true
        defer {
            isSyncing = false
            updatePendingCount()
        }

        let operations = databaseManager.fetchPendingOperations()
        guard !operations.isEmpty else { return }

        var didMutateRemoteData = false

        for operation in operations {
            let success = await processOperation(operation)

            if success {
                didMutateRemoteData = true
                databaseManager.deletePendingOperation(id: operation.id)
                continue
            }

            if operation.retryCount >= 3 {
                databaseManager.deletePendingOperation(id: operation.id)
                continue
            }

            databaseManager.incrementRetryCount(id: operation.id)

            if NetworkErrorHeuristics.isLikelyConnectivityIssue(networkService.lastError) {
                break
            }
        }

        if didMutateRemoteData {
            _ = await MovieRepository.shared.syncPeople()
            _ = await MovieRepository.shared.syncMovies()
        }
    }

    func enrichPendingMovies() async {
        let pendingMovies = databaseManager.fetchPendingMovies()
        guard !pendingMovies.isEmpty else {
            updatePendingCount()
            return
        }
        AppLog.info(
            "Pending offline movies awaiting manual match selection: \(pendingMovies.count)",
            category: .database
        )
        updatePendingCount()
    }

    private func processOperation(_ operation: DatabaseManager.PendingOperation) async -> Bool {
        switch operation.type {
        case PendingOperationType.addMovie:
            guard let payload: AddMovieOperationPayload = decodePayload(from: operation) else {
                return false
            }
            return await networkService.addMovie(
                tmdbId: payload.tmdbId,
                recommender: payload.recommender,
                mediaType: payload.mediaType
            )

        case PendingOperationType.addMovieBulk:
            guard let payload: AddMovieBulkOperationPayload = decodePayload(from: operation) else {
                return false
            }
            return await networkService.addMovieBulk(
                tmdbId: payload.tmdbId,
                recommenders: payload.recommenders,
                mediaType: payload.mediaType
            )

        case PendingOperationType.addRecommendation:
            guard let payload: AddRecommendationOperationPayload = decodePayload(from: operation) else {
                return false
            }
            return await networkService.addRecommendation(
                imdbId: payload.imdbId,
                person: payload.recommender,
                voteType: payload.voteType
            )

        case PendingOperationType.removeRecommendation:
            guard let payload: RemoveRecommendationOperationPayload = decodePayload(from: operation) else {
                return false
            }
            return await networkService.removeRecommendation(imdbId: payload.imdbId, person: payload.recommender)

        case PendingOperationType.updateMovie:
            guard let payload: UpdateMovieOperationPayload = decodePayload(from: operation) else {
                return false
            }

            let movie = placeholderMovie(imdbId: payload.imdbId, status: payload.status)
            await networkService.updateMovie(movie: movie, rating: payload.rating, status: payload.status)
            return networkService.lastError == nil

        case PendingOperationType.updatePerson:
            guard let payload: UpdatePersonOperationPayload = decodePayload(from: operation) else {
                return false
            }

            await networkService.updatePerson(name: payload.name, isTrusted: payload.isTrusted)
            return networkService.lastError == nil

        default:
            return false
        }
    }

    private func decodePayload<T: Decodable>(from operation: DatabaseManager.PendingOperation) -> T? {
        guard let payloadData = operation.payload.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: payloadData)
    }

    private func placeholderMovie(imdbId: String, status: String?) -> Movie {
        let digits = imdbId.filter(\.isNumber)
        let hash = imdbId.hashValue
        let fallbackId = Int(digits) ?? (hash == Int.min ? 0 : abs(hash))

        return Movie(
            id: fallbackId,
            imdbId: imdbId,
            tmdbId: nil,
            title: imdbId,
            posterPath: nil,
            overview: nil,
            releaseDate: nil,
            voteAverage: nil,
            status: status ?? "to_watch",
            myRating: nil,
            dateWatched: nil,
            mediaType: "movie",
            recommendations: []
        )
    }

    private func updatePendingCount() {
        pendingCount = databaseManager.pendingOperationsCount + databaseManager.pendingMoviesCount
    }

}
