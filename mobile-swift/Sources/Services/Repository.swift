import Foundation

@MainActor
protocol DataRepository {
    func getMovies(status: String?) async -> Result<[Movie], RepositoryError>
    func getPeople() async -> Result<[Person], RepositoryError>
    func getPersonMovies(personName: String) async -> Result<[Movie], RepositoryError>
    func addMovie(tmdbId: Int, recommender: String) async -> Result<Movie, RepositoryError>
    func addMovieBulk(tmdbId: Int, recommenders: [String]) async -> Result<Void, RepositoryError>
    func addRecommender(movie: Movie, recommender: String) async -> Result<Movie, RepositoryError>
    func removeRecommender(movie: Movie, recommender: String) async -> Result<Movie, RepositoryError>
    func queueMovieByTitle(title: String, recommender: String) async -> Result<String, RepositoryError>
    func updateMovie(movie: Movie, rating: Int?, status: String?) async -> Result<Movie, RepositoryError>
    func refreshMovieMetadata(imdbId: String) async -> Result<Movie, RepositoryError>
    func updatePerson(name: String, isTrusted: Bool) async -> Result<Void, RepositoryError>
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
}

struct AddMovieBulkOperationPayload: Codable {
    let tmdbId: Int
    let recommenders: [String]
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
