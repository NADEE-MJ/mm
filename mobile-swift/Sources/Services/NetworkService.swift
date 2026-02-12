import Foundation

// MARK: - Data Models

struct Movie: Identifiable, Hashable, Decodable {
    let id: Int
    let imdbId: String
    let tmdbId: Int?
    let title: String
    let posterPath: String?
    let overview: String?
    let releaseDate: String?
    let voteAverage: Double?
    let genres: [String]
    let director: String?
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
        case imdbId = "imdb_id"
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
        if let backendMovie = try? BackendMovie(from: decoder) {
            let backendStatus = backendMovie.status ?? "toWatch"
            let mappedRecommendations = backendMovie.recommendations.map {
                Recommendation(
                    recommender: $0.person,
                    dateRecommended: Self.formatUnixTimestamp($0.dateRecommended)
                )
            }

            let tmdbData = backendMovie.tmdbData
            let omdbData = backendMovie.omdbData
            let fallbackId = Self.stableID(from: backendMovie.imdbId)

            id = tmdbData?.tmdbId ?? fallbackId
            imdbId = backendMovie.imdbId
            tmdbId = tmdbData?.tmdbId
            title = tmdbData?.title ?? omdbData?.title ?? backendMovie.imdbId
            posterPath = tmdbData?.poster ?? tmdbData?.posterPath ?? omdbData?.poster
            overview = tmdbData?.plot ?? omdbData?.plot
            releaseDate = tmdbData?.year ?? omdbData?.yearString
            voteAverage = tmdbData?.voteAverage ?? omdbData?.imdbRating
            let omdbGenres = omdbData?.genres ?? []
            let tmdbGenres = tmdbData?.genres ?? []
            genres = omdbGenres.isEmpty ? tmdbGenres : omdbGenres
            director = omdbData?.director
            status = Self.mapBackendStatusToApp(backendStatus)
            if let watchHistory = backendMovie.watchHistory {
                myRating = Int(round(watchHistory.myRating))
                dateWatched = Self.formatUnixTimestamp(watchHistory.dateWatched)
            } else {
                myRating = nil
                dateWatched = nil
            }
            recommendations = mappedRecommendations
            return
        }

        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacyId = try c.decode(Int.self, forKey: .id)

        id = legacyId
        imdbId = (try? c.decode(String.self, forKey: .imdbId)) ?? String(legacyId)
        tmdbId = try c.decodeIfPresent(Int.self, forKey: .tmdbId)
        title = try c.decode(String.self, forKey: .title)
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        releaseDate = try c.decodeIfPresent(String.self, forKey: .releaseDate)
        voteAverage = try c.decodeIfPresent(Double.self, forKey: .voteAverage)
        genres = []
        director = nil
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "to_watch"
        myRating = try c.decodeIfPresent(Int.self, forKey: .myRating)
        dateWatched = try c.decodeIfPresent(String.self, forKey: .dateWatched)
        recommendations = (try? c.decodeIfPresent([Recommendation].self, forKey: .recommendations)) ?? []
    }

    init(
        id: Int,
        imdbId: String,
        tmdbId: Int?,
        title: String,
        posterPath: String?,
        overview: String?,
        releaseDate: String?,
        voteAverage: Double?,
        genres: [String] = [],
        director: String? = nil,
        status: String,
        myRating: Int?,
        dateWatched: String?,
        recommendations: [Recommendation]
    ) {
        self.id = id
        self.imdbId = imdbId
        self.tmdbId = tmdbId
        self.title = title
        self.posterPath = posterPath
        self.overview = overview
        self.releaseDate = releaseDate
        self.voteAverage = voteAverage
        self.genres = genres
        self.director = director
        self.status = status
        self.myRating = myRating
        self.dateWatched = dateWatched
        self.recommendations = recommendations
    }

    private static func mapBackendStatusToApp(_ backendStatus: String) -> String {
        switch backendStatus {
        case "toWatch", "to_watch":
            return "to_watch"
        default:
            return backendStatus
        }
    }

    private static func stableID(from imdbId: String) -> Int {
        let digits = imdbId.filter(\.isNumber)
        if let parsed = Int(digits), parsed > 0 {
            return parsed
        }

        // Deterministic fallback when tmdb id is absent.
        var hash = 5381
        for scalar in imdbId.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }

    private static func formatUnixTimestamp(_ seconds: Double) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }
}

struct Recommendation: Hashable, Decodable {
    let recommender: String
    let dateRecommended: String

    enum CodingKeys: String, CodingKey {
        case recommender
        case person
        case dateRecommended = "date_recommended"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let recommenderValue = try? c.decode(String.self, forKey: .recommender) {
            recommender = recommenderValue
        } else {
            recommender = try c.decode(String.self, forKey: .person)
        }

        if let dateString = try? c.decode(String.self, forKey: .dateRecommended) {
            dateRecommended = dateString
        } else if let dateEpoch = try? c.decode(Double.self, forKey: .dateRecommended) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            dateRecommended = formatter.string(from: Date(timeIntervalSince1970: dateEpoch))
        } else {
            dateRecommended = ""
        }
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

struct TMDBMovie: Identifiable, Hashable, Decodable {
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
        case poster
        case posterSmall
        case overview
        case releaseDate = "release_date"
        case year
        case voteAverage = "vote_average"
        case voteAverageCamel = "voteAverage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? "Untitled"

        if let poster = try? c.decode(String.self, forKey: .poster) {
            posterPath = poster
        } else if let posterSmall = try? c.decode(String.self, forKey: .posterSmall) {
            posterPath = posterSmall
        } else {
            posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        }

        overview = try c.decodeIfPresent(String.self, forKey: .overview)

        if let release = try? c.decode(String.self, forKey: .releaseDate) {
            releaseDate = release
        } else if let yearString = try? c.decode(String.self, forKey: .year) {
            releaseDate = yearString
        } else if let yearInt = try? c.decode(Int.self, forKey: .year) {
            releaseDate = String(yearInt)
        } else {
            releaseDate = nil
        }

        if let vote = try? c.decode(Double.self, forKey: .voteAverage) {
            voteAverage = vote
        } else {
            voteAverage = try c.decodeIfPresent(Double.self, forKey: .voteAverageCamel)
        }
    }

    init(id: Int, title: String, posterPath: String?, overview: String?, releaseDate: String?, voteAverage: Double?) {
        self.id = id
        self.title = title
        self.posterPath = posterPath
        self.overview = overview
        self.releaseDate = releaseDate
        self.voteAverage = voteAverage
    }
}

private struct TMDBSearchResponse: Decodable {
    let results: [TMDBMovie]
}

private struct BackendRecommendation: Decodable {
    let person: String
    let dateRecommended: Double

    enum CodingKeys: String, CodingKey {
        case person
        case dateRecommended = "date_recommended"
    }
}

private struct BackendWatchHistory: Decodable {
    let myRating: Double
    let dateWatched: Double

    enum CodingKeys: String, CodingKey {
        case myRating = "my_rating"
        case dateWatched = "date_watched"
    }
}

private struct TMDBDetailPayload: Codable {
    let tmdbId: Int?
    let imdbId: String?
    let title: String?
    let year: String?
    let poster: String?
    let posterSmall: String?
    let posterPath: String?
    let plot: String?
    let genres: [String]?
    let voteAverage: Double?
    let voteCount: Int?

    enum CodingKeys: String, CodingKey {
        case tmdbId
        case imdbId
        case title
        case year
        case poster
        case posterSmall
        case posterPath = "poster_path"
        case plot
        case genres
        case voteAverage
        case voteCount
    }

    private enum AlternateDecodingKeys: String, CodingKey {
        case voteAverageSnake = "vote_average"
        case voteCountSnake = "vote_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try c.decodeIfPresent(Int.self, forKey: .tmdbId)
        imdbId = try c.decodeIfPresent(String.self, forKey: .imdbId)
        title = try c.decodeIfPresent(String.self, forKey: .title)

        if let yearString = try? c.decode(String.self, forKey: .year) {
            year = yearString
        } else if let yearInt = try? c.decode(Int.self, forKey: .year) {
            year = String(yearInt)
        } else {
            year = nil
        }

        poster = try c.decodeIfPresent(String.self, forKey: .poster)
        posterSmall = try c.decodeIfPresent(String.self, forKey: .posterSmall)
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        plot = try c.decodeIfPresent(String.self, forKey: .plot)
        genres = try c.decodeIfPresent([String].self, forKey: .genres)
        var decodedVoteAverage = try c.decodeIfPresent(Double.self, forKey: .voteAverage)
        var decodedVoteCount = try c.decodeIfPresent(Int.self, forKey: .voteCount)

        if decodedVoteAverage == nil || decodedVoteCount == nil {
            let alt = try decoder.container(keyedBy: AlternateDecodingKeys.self)
            if decodedVoteAverage == nil {
                decodedVoteAverage = try alt.decodeIfPresent(Double.self, forKey: .voteAverageSnake)
            }
            if decodedVoteCount == nil {
                decodedVoteCount = try alt.decodeIfPresent(Int.self, forKey: .voteCountSnake)
            }
        }

        voteAverage = decodedVoteAverage
        voteCount = decodedVoteCount
    }

    init(
        tmdbId: Int?,
        imdbId: String?,
        title: String?,
        year: String?,
        poster: String?,
        posterSmall: String?,
        posterPath: String?,
        plot: String?,
        genres: [String]?,
        voteAverage: Double?,
        voteCount: Int?
    ) {
        self.tmdbId = tmdbId
        self.imdbId = imdbId
        self.title = title
        self.year = year
        self.poster = poster
        self.posterSmall = posterSmall
        self.posterPath = posterPath
        self.plot = plot
        self.genres = genres
        self.voteAverage = voteAverage
        self.voteCount = voteCount
    }
}

private struct OMDBDetailPayload: Codable {
    let imdbId: String?
    let title: String?
    let year: Int?
    let plot: String?
    let poster: String?
    let genres: [String]?
    let director: String?
    let imdbRating: Double?

    enum CodingKeys: String, CodingKey {
        case imdbId
        case title
        case year
        case plot
        case poster
        case genres
        case director
        case imdbRating
    }

    var yearString: String? {
        guard let year else { return nil }
        return String(year)
    }
}

private struct BackendMovie: Decodable {
    let imdbId: String
    let tmdbData: TMDBDetailPayload?
    let omdbData: OMDBDetailPayload?
    let status: String?
    let recommendations: [BackendRecommendation]
    let watchHistory: BackendWatchHistory?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case tmdbData = "tmdb_data"
        case omdbData = "omdb_data"
        case status
        case recommendations
        case watchHistory = "watch_history"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imdbId = try c.decode(String.self, forKey: .imdbId)
        tmdbData = try c.decodeIfPresent(TMDBDetailPayload.self, forKey: .tmdbData)
        omdbData = try c.decodeIfPresent(OMDBDetailPayload.self, forKey: .omdbData)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        recommendations = (try? c.decodeIfPresent([BackendRecommendation].self, forKey: .recommendations)) ?? []
        watchHistory = try c.decodeIfPresent(BackendWatchHistory.self, forKey: .watchHistory)
    }
}

private struct AddRecommendationRequest: Encodable {
    let person: String
    let voteType: String
    let tmdbData: TMDBDetailPayload?
    let omdbData: OMDBDetailPayload?

    enum CodingKeys: String, CodingKey {
        case person
        case voteType = "vote_type"
        case tmdbData = "tmdb_data"
        case omdbData = "omdb_data"
    }
}

private struct BulkAddRecommendationRequest: Encodable {
    let people: [String]
    let voteType: String
    let tmdbData: TMDBDetailPayload?
    let omdbData: OMDBDetailPayload?

    enum CodingKeys: String, CodingKey {
        case people
        case voteType = "vote_type"
        case tmdbData = "tmdb_data"
        case omdbData = "omdb_data"
    }
}

private struct UpdateMovieStatusRequest: Encodable {
    let status: String
    let customListId: String?

    enum CodingKeys: String, CodingKey {
        case status
        case customListId = "custom_list_id"
    }
}

private struct MarkWatchedRequest: Encodable {
    let dateWatched: Double
    let myRating: Double

    enum CodingKeys: String, CodingKey {
        case dateWatched = "date_watched"
        case myRating = "my_rating"
    }
}

private struct UpdatePersonRequest: Encodable {
    let isTrusted: Bool

    enum CodingKeys: String, CodingKey {
        case isTrusted = "is_trusted"
    }
}

private struct AddPersonRequest: Encodable {
    let name: String
    let isTrusted: Bool

    enum CodingKeys: String, CodingKey {
        case name
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
        AppLog.debug("🌐 [NetworkService] Initialized with baseURL: \(baseURL)", category: .network)
    }

    // MARK: - Movies

    func fetchMovies(status: String? = nil) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let data = await get("\(baseURL)/movies") else { return }
        guard let decoded = try? JSONDecoder().decode([Movie].self, from: data) else {
            lastError = "Failed to decode movies response"
            AppLog.error("🌐 [NetworkService] Failed to decode /movies response", category: .network)
            return
        }

        if let status {
            let wantedStatus = normalizeAppStatus(status)
            movies = decoded.filter { normalizeAppStatus($0.status) == wantedStatus }
        } else {
            movies = decoded
        }
    }

    func addMovie(tmdbId: Int, recommender: String) async -> Bool {
        let trimmedRecommender = recommender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecommender.isEmpty else {
            lastError = "Recommender is required"
            return false
        }

        guard let tmdbDetails = await fetchTMDBDetails(tmdbId: tmdbId) else {
            return false
        }

        guard let imdbId = tmdbDetails.imdbId, !imdbId.isEmpty else {
            lastError = "TMDB details are missing imdbId"
            AppLog.error("🌐 [NetworkService] Missing imdbId in TMDB details for tmdbId=\(tmdbId)", category: .network)
            return false
        }

        let omdbDetails = await fetchOMDBDetails(imdbId: imdbId)

        guard let encodedImdb = imdbId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            lastError = "Invalid imdb id: \(imdbId)"
            return false
        }

        let body = AddRecommendationRequest(
            person: trimmedRecommender,
            voteType: "upvote",
            tmdbData: tmdbDetails,
            omdbData: omdbDetails
        )

        return await post(
            "\(baseURL)/movies/\(encodedImdb)/recommendations",
            body: body,
            validStatusCodes: [200, 201]
        )
    }

    func addMovieBulk(tmdbId: Int, recommenders: [String]) async -> Bool {
        let trimmedRecommenders = recommenders.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmedRecommenders.isEmpty else {
            lastError = "At least one recommender is required"
            return false
        }

        guard let tmdbDetails = await fetchTMDBDetails(tmdbId: tmdbId) else {
            return false
        }

        guard let imdbId = tmdbDetails.imdbId, !imdbId.isEmpty else {
            lastError = "TMDB details are missing imdbId"
            AppLog.error("🌐 [NetworkService] Missing imdbId in TMDB details for tmdbId=\(tmdbId)", category: .network)
            return false
        }

        let omdbDetails = await fetchOMDBDetails(imdbId: imdbId)

        guard let encodedImdb = imdbId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            lastError = "Invalid imdb id: \(imdbId)"
            return false
        }

        let body = BulkAddRecommendationRequest(
            people: trimmedRecommenders,
            voteType: "upvote",
            tmdbData: tmdbDetails,
            omdbData: omdbDetails
        )

        return await post(
            "\(baseURL)/movies/\(encodedImdb)/recommendations/bulk",
            body: body,
            validStatusCodes: [200, 201]
        )
    }

    func updateMovie(movie: Movie, rating: Int?, status: String?) async {
        guard let encodedImdb = movie.imdbId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            lastError = "Invalid imdb id: \(movie.imdbId)"
            return
        }

        if let rating {
            let safeRating = min(10, max(1, rating))
            let watchBody = MarkWatchedRequest(
                dateWatched: Date().timeIntervalSince1970,
                myRating: Double(safeRating)
            )
            let watchedUpdated = await put(
                "\(baseURL)/movies/\(encodedImdb)/watch",
                body: watchBody,
                validStatusCodes: [200]
            )

            if !watchedUpdated {
                return
            }

            if let status, normalizeBackendStatus(status) != "watched" {
                let statusBody = UpdateMovieStatusRequest(
                    status: normalizeBackendStatus(status),
                    customListId: nil
                )
                _ = await put(
                    "\(baseURL)/movies/\(encodedImdb)/status",
                    body: statusBody,
                    validStatusCodes: [200]
                )
            }
            return
        }

        if let status {
            let statusBody = UpdateMovieStatusRequest(
                status: normalizeBackendStatus(status),
                customListId: nil
            )
            _ = await put(
                "\(baseURL)/movies/\(encodedImdb)/status",
                body: statusBody,
                validStatusCodes: [200]
            )
        }
    }

    // MARK: - TMDB Search

    func searchMovies(query: String) async -> [TMDBMovie] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let data = await get("\(baseURL)/external/tmdb/search?q=\(encoded)")
        else {
            return []
        }

        if let decodedArray = try? JSONDecoder().decode([TMDBMovie].self, from: data) {
            return decodedArray
        }

        if let wrapped = try? JSONDecoder().decode(TMDBSearchResponse.self, from: data) {
            return wrapped.results
        }

        lastError = "Failed to decode TMDB search response"
        AppLog.warning("🌐 [NetworkService] Could not decode TMDB search response", category: .network)
        return []
    }

    // MARK: - People

    func fetchPeople() async {
        guard let data = await get("\(baseURL)/people") else { return }
        if let decoded = try? JSONDecoder().decode([Person].self, from: data) {
            people = decoded
        } else {
            lastError = "Failed to decode people response"
            AppLog.warning("🌐 [NetworkService] Could not decode /people response", category: .network)
        }
    }

    func fetchPersonMovies(personName: String) async -> [Movie] {
        guard let encodedName = personName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            lastError = "Invalid person name"
            return []
        }

        guard let data = await get("\(baseURL)/people/\(encodedName)/stats") else { return [] }

        struct PersonStats: Decodable {
            let movies: [Movie]
        }

        if let decoded = try? JSONDecoder().decode(PersonStats.self, from: data) {
            return decoded.movies
        } else {
            lastError = "Failed to decode person stats response"
            AppLog.warning("🌐 [NetworkService] Could not decode /people/\(personName)/stats response", category: .network)
            return []
        }
    }

    func addPerson(name: String, isTrusted: Bool) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Person name is required"
            return false
        }

        let body = AddPersonRequest(name: trimmed, isTrusted: isTrusted)
        return await post(
            "\(baseURL)/people",
            body: body,
            validStatusCodes: [200, 201]
        )
    }

    func updatePerson(name: String, isTrusted: Bool) async {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        let body = UpdatePersonRequest(isTrusted: isTrusted)
        _ = await put("\(baseURL)/people/\(encoded)", body: body, validStatusCodes: [200])
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
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(status) else {
                handleHTTPError(method: "GET", urlString: urlString, status: status, data: data)
                return nil
            }
            return data
        } catch {
            lastError = error.localizedDescription
            AppLog.error("🌐 [NetworkService] GET failed: \(error.localizedDescription) @ \(urlString)", category: .network)
            return nil
        }
    }

    private func post<T: Encodable>(
        _ urlString: String,
        body: T,
        validStatusCodes: Set<Int> = [200]
    ) async -> Bool {
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

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard validStatusCodes.contains(status) else {
                handleHTTPError(method: "POST", urlString: urlString, status: status, data: data)
                return false
            }
            return true
        } catch {
            lastError = error.localizedDescription
            AppLog.error("🌐 [NetworkService] POST failed: \(error.localizedDescription) @ \(urlString)", category: .network)
            return false
        }
    }

    private func put<T: Encodable>(
        _ urlString: String,
        body: T,
        validStatusCodes: Set<Int> = [200]
    ) async -> Bool {
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

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard validStatusCodes.contains(status) else {
                handleHTTPError(method: "PUT", urlString: urlString, status: status, data: data)
                return false
            }
            return true
        } catch {
            lastError = error.localizedDescription
            AppLog.error("🌐 [NetworkService] PUT failed: \(error.localizedDescription) @ \(urlString)", category: .network)
            return false
        }
    }

    private func handleHTTPError(method: String, urlString: String, status: Int, data: Data) {
        let bodyString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bodyString, !bodyString.isEmpty {
            lastError = "\(method) \(urlString) failed (HTTP \(status)): \(bodyString)"
            AppLog.warning(
                "🌐 [NetworkService] \(method) HTTP \(status) @ \(urlString) body=\(bodyString)",
                category: .network
            )
        } else {
            lastError = "\(method) \(urlString) failed (HTTP \(status))"
            AppLog.warning(
                "🌐 [NetworkService] \(method) HTTP \(status) @ \(urlString)",
                category: .network
            )
        }
    }

    private func fetchTMDBDetails(tmdbId: Int) async -> TMDBDetailPayload? {
        guard let data = await get("\(baseURL)/external/tmdb/movie/\(tmdbId)") else {
            return nil
        }

        guard let details = try? JSONDecoder().decode(TMDBDetailPayload.self, from: data) else {
            lastError = "Failed to decode TMDB details for tmdb id \(tmdbId)"
            AppLog.warning("🌐 [NetworkService] Could not decode TMDB details for \(tmdbId)", category: .network)
            return nil
        }

        return details
    }

    private func fetchOMDBDetails(imdbId: String) async -> OMDBDetailPayload? {
        guard let encodedImdb = imdbId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        guard let data = await get("\(baseURL)/external/omdb/movie/\(encodedImdb)") else {
            return nil
        }

        return try? JSONDecoder().decode(OMDBDetailPayload.self, from: data)
    }

    private func normalizeBackendStatus(_ appStatus: String) -> String {
        switch appStatus {
        case "to_watch", "toWatch":
            return "toWatch"
        default:
            return appStatus
        }
    }

    private func normalizeAppStatus(_ status: String) -> String {
        switch status {
        case "toWatch", "to_watch":
            return "to_watch"
        default:
            return status
        }
    }
}
