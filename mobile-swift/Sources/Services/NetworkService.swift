import Foundation

// MARK: - Data Models

struct Movie: Identifiable, Hashable, Codable {
    let id: Int
    let tmdbId: Int?
    let title: String
    let posterPath: String?
    let overview: String?
    let releaseDate: String?
    let voteAverage: Double?
    let status: String
    let myRating: Int?
    let dateWatched: String?
    let recommendations: [Recommendation]

    var posterURL: URL? {
        guard let posterPath else { return nil }
        if posterPath.hasPrefix("http") { return URL(string: posterPath) }
        return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case overview
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case status
        case myRating = "my_rating"
        case dateWatched = "date_watched"
        case recommendations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        tmdbId = try c.decodeIfPresent(Int.self, forKey: .tmdbId)
        title = try c.decode(String.self, forKey: .title)
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        releaseDate = try c.decodeIfPresent(String.self, forKey: .releaseDate)
        voteAverage = try c.decodeIfPresent(Double.self, forKey: .voteAverage)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "to_watch"
        myRating = try c.decodeIfPresent(Int.self, forKey: .myRating)
        dateWatched = try c.decodeIfPresent(String.self, forKey: .dateWatched)
        recommendations = (try? c.decodeIfPresent([Recommendation].self, forKey: .recommendations)) ?? []
    }

    init(id: Int, tmdbId: Int?, title: String, posterPath: String?,
         overview: String?, releaseDate: String?, voteAverage: Double?,
         status: String, myRating: Int?, dateWatched: String?,
         recommendations: [Recommendation]) {
        self.id = id; self.tmdbId = tmdbId; self.title = title
        self.posterPath = posterPath; self.overview = overview
        self.releaseDate = releaseDate; self.voteAverage = voteAverage
        self.status = status; self.myRating = myRating
        self.dateWatched = dateWatched; self.recommendations = recommendations
    }
}

struct Recommendation: Hashable, Codable {
    let recommender: String
    let dateRecommended: String

    enum CodingKeys: String, CodingKey {
        case recommender
        case dateRecommended = "date_recommended"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recommender = try c.decode(String.self, forKey: .recommender)
        dateRecommended = (try? c.decode(String.self, forKey: .dateRecommended)) ?? ""
    }

    init(recommender: String, dateRecommended: String) {
        self.recommender = recommender
        self.dateRecommended = dateRecommended
    }
}

struct Person: Identifiable, Hashable, Codable {
    let name: String
    let isTrusted: Bool
    let movieCount: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case isTrusted = "is_trusted"
        case movieCount = "movie_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        isTrusted = (try? c.decode(Bool.self, forKey: .isTrusted)) ?? false
        movieCount = (try? c.decode(Int.self, forKey: .movieCount)) ?? 0
    }

    init(name: String, isTrusted: Bool, movieCount: Int) {
        self.name = name
        self.isTrusted = isTrusted
        self.movieCount = movieCount
    }
}

struct TMDBMovie: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let posterPath: String?
    let overview: String?
    let releaseDate: String?
    let voteAverage: Double?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        if posterPath.hasPrefix("http") { return URL(string: posterPath) }
        return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case posterPath = "poster_path"
        case overview
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}

private struct TMDBSearchResponse: Codable {
    let results: [TMDBMovie]
}

private struct AddMovieRequest: Encodable {
    let tmdbId: Int
    let recommender: String

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case recommender
    }
}

private struct UpdateMovieRequest: Encodable {
    let rating: Int?
    let status: String?
}

private struct UpdatePersonRequest: Encodable {
    let isTrusted: Bool

    enum CodingKeys: String, CodingKey {
        case isTrusted = "is_trusted"
    }
}

// MARK: - Network Service

@MainActor
@Observable
final class NetworkService {
    static let shared = NetworkService()

    private(set) var movies: [Movie] = []
    private(set) var people: [Person] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let session = URLSession.shared
    private let baseURL: String

    private init() {
        baseURL = AppConfiguration.apiBaseURLString
        
        // Debug: Log the configured API base URL
        AppLog.debug("🌐 [NetworkService] Initialized with baseURL: \(baseURL)", category: .network)
        AppLog.debug("🌐 [NetworkService] Info.plist API_BASE_URL: \(baseURL)", category: .network)
    }

    // MARK: - Movies

    func fetchMovies(status: String? = nil) async {
        isLoading = true; lastError = nil
        defer { isLoading = false }

        var url = "\(baseURL)/movies"
        if let status { url += "?status=\(status)" }

        guard let data = await get(url) else { return }
        if let decoded = try? JSONDecoder().decode([Movie].self, from: data) {
            movies = decoded
        }
    }

    func addMovie(tmdbId: Int, recommender: String) async -> Bool {
        let body = AddMovieRequest(tmdbId: tmdbId, recommender: recommender)
        return await post("\(baseURL)/movies", body: body)
    }

    func updateMovie(id: Int, rating: Int?, status: String?) async {
        let body = UpdateMovieRequest(rating: rating, status: status)
        _ = await put("\(baseURL)/movies/\(id)", body: body)
    }

    // MARK: - TMDB Search

    func searchMovies(query: String) async -> [TMDBMovie] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let data = await get("\(baseURL)/external/tmdb/search?q=\(encoded)")
        else { return [] }
        return (try? JSONDecoder().decode(TMDBSearchResponse.self, from: data))?.results ?? []
    }

    // MARK: - People

    func fetchPeople() async {
        guard let data = await get("\(baseURL)/people") else { return }
        if let decoded = try? JSONDecoder().decode([Person].self, from: data) {
            people = decoded
        }
    }

    func updatePerson(name: String, isTrusted: Bool) async {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        let body = UpdatePersonRequest(isTrusted: isTrusted)
        _ = await put("\(baseURL)/people/\(encoded)", body: body)
    }

    // MARK: - HTTP Helpers

    private var authHeaders: [String: String] {
        var headers: [String: String] = [:]
        if let token = AuthManager.shared.token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    private func get(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else {
            AppLog.error("🌐 [NetworkService] Invalid URL in GET: \(urlString)", category: .network)
            return nil
        }
        var request = URLRequest(url: url)
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, _) = try await session.data(for: request)
            return data
        } catch {
            lastError = error.localizedDescription
            AppLog.error("🌐 [NetworkService] GET failed: \(error.localizedDescription) @ \(urlString)", category: .network)
            return nil
        }
    }

    private func post<T: Encodable>(_ urlString: String, body: T) async -> Bool {
        guard let url = URL(string: urlString) else {
            AppLog.error("🌐 [NetworkService] Invalid URL in POST: \(urlString)", category: .network)
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (_, response) = try await session.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if !ok {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                AppLog.warning("🌐 [NetworkService] POST returned status \(status) @ \(urlString)", category: .network)
            }
            return ok
        } catch {
            lastError = error.localizedDescription
            AppLog.error("🌐 [NetworkService] POST failed: \(error.localizedDescription) @ \(urlString)", category: .network)
            return false
        }
    }

    private func put<T: Encodable>(_ urlString: String, body: T) async -> Bool {
        guard let url = URL(string: urlString) else {
            AppLog.error("🌐 [NetworkService] Invalid URL in PUT: \(urlString)", category: .network)
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (_, response) = try await session.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if !ok {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                AppLog.warning("🌐 [NetworkService] PUT returned status \(status) @ \(urlString)", category: .network)
            }
            return ok
        } catch {
            lastError = error.localizedDescription
            AppLog.error("🌐 [NetworkService] PUT failed: \(error.localizedDescription) @ \(urlString)", category: .network)
            return false
        }
    }
}
