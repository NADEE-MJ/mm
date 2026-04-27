import Foundation

@MainActor
protocol DataRepository {
    func getMovies(status: String?) async -> Result<[Movie], RepositoryError>
    func getPeople() async -> Result<[Person], RepositoryError>
    func getPersonMovies(personName: String) async -> Result<[Movie], RepositoryError>
    func addMovie(tmdbId: Int, recommender: String, mediaType: String) async -> Result<Movie, RepositoryError>
    func addMovieBulk(tmdbId: Int, recommenders: [String], mediaType: String) async -> Result<Void, RepositoryError>
    func addRecommender(movie: Movie, recommender: String) async -> Result<Movie, RepositoryError>
    func removeRecommender(movie: Movie, recommender: String) async -> Result<Movie, RepositoryError>
    func queueMovieByTitle(title: String, recommender: String) async -> Result<String, RepositoryError>
    func updateMovie(movie: Movie, rating: Int?, status: String?) async -> Result<Movie, RepositoryError>
    func refreshMovieMetadata(imdbId: String) async -> Result<Movie, RepositoryError>
    func updatePerson(name: String, isTrusted: Bool) async -> Result<Void, RepositoryError>
    func renamePerson(name: String, newName: String) async -> Result<Void, RepositoryError>
    func syncNow() async
    func performInitialSyncIfNeeded() async
    var isSyncing: Bool { get }
}

enum RepositoryError: Error {
    case networkError(String)
    case databaseError(String)
    case notFound(String)
    case queued(String)
}

enum PendingOperationType {
    static let addMovie = "add_movie"
    static let addMovieBulk = "add_movie_bulk"
    static let addRecommendation = "add_recommendation"
    static let removeRecommendation = "remove_recommendation"
    static let updateMovie = "update_movie"
    static let updatePerson = "update_person"
}

struct AddMovieOperationPayload: Codable {
    let tmdbId: Int
    let recommender: String
    let mediaType: String

    init(tmdbId: Int, recommender: String, mediaType: String = "movie") {
        self.tmdbId = tmdbId
        self.recommender = recommender
        self.mediaType = mediaType
    }

    private enum CodingKeys: String, CodingKey {
        case tmdbId
        case recommender
        case mediaType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try c.decode(Int.self, forKey: .tmdbId)
        recommender = try c.decode(String.self, forKey: .recommender)
        mediaType = (try? c.decode(String.self, forKey: .mediaType)) ?? "movie"
    }
}

struct AddMovieBulkOperationPayload: Codable {
    let tmdbId: Int
    let recommenders: [String]
    let mediaType: String

    init(tmdbId: Int, recommenders: [String], mediaType: String = "movie") {
        self.tmdbId = tmdbId
        self.recommenders = recommenders
        self.mediaType = mediaType
    }

    private enum CodingKeys: String, CodingKey {
        case tmdbId
        case recommenders
        case mediaType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try c.decode(Int.self, forKey: .tmdbId)
        recommenders = try c.decode([String].self, forKey: .recommenders)
        mediaType = (try? c.decode(String.self, forKey: .mediaType)) ?? "movie"
    }
}

struct AddRecommendationOperationPayload: Codable {
    let imdbId: String
    let recommender: String
    let voteType: String

    enum CodingKeys: String, CodingKey {
        case imdbId
        case recommender
        case voteType
    }

    init(imdbId: String, recommender: String, voteType: String = "upvote") {
        self.imdbId = imdbId
        self.recommender = recommender
        self.voteType = voteType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imdbId = try c.decode(String.self, forKey: .imdbId)
        recommender = try c.decode(String.self, forKey: .recommender)
        voteType = (try? c.decode(String.self, forKey: .voteType)) ?? "upvote"
    }
}

struct RemoveRecommendationOperationPayload: Codable {
    let imdbId: String
    let recommender: String
}

struct UpdateMovieOperationPayload: Codable {
    let imdbId: String
    let rating: Int?
    let status: String?
}

struct UpdatePersonOperationPayload: Codable {
    let name: String
    let isTrusted: Bool
}

extension RepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return message
        case .databaseError(let message):
            return message
        case .notFound(let message):
            return message
        case .queued(let message):
            return message
        }
    }
}

enum DateFormatting {
    private static func fractionalFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func internetFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static func isoTimestampNow() -> String {
        fractionalFormatter().string(from: .now)
    }

    static func isoTimestamp(fromEpochSeconds seconds: Double) -> String {
        fractionalFormatter().string(from: Date(timeIntervalSince1970: seconds))
    }

    static func parseISODate(_ value: String) -> Date? {
        if let date = fractionalFormatter().date(from: value) {
            return date
        }
        return internetFormatter().date(from: value)
    }
}

enum NetworkErrorHeuristics {
    private static let markers: [String] = [
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
        "socket",
    ]

    static func isLikelyConnectivityIssue(_ message: String?) -> Bool {
        guard let message else { return false }
        let text = message.lowercased()
        return markers.contains { text.contains($0) }
    }
}
