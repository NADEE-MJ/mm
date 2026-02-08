import Foundation

// MARK: - Network Service
// Handles API requests to the Movie Manager backend

@MainActor
@Observable
final class NetworkService {
    static let shared = NetworkService()

    private(set) var isLoading = false
    private(set) var lastError: String?
    
    // API data
    private(set) var movies: [Movie] = []
    private(set) var people: [Person] = []

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // TODO: Replace with actual API URL or load from environment
    private let baseURL = "http://localhost:8000/api"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Movies

    func fetchMovies(status: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        var urlString = "\(baseURL)/movies"
        if let status = status {
            urlString += "?status=\(status)"
        }
        
        guard let url = URL(string: urlString) else {
            setError("Invalid URL")
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                setError("Bad response")
                return
            }

            movies = try decoder.decode([Movie].self, from: data)
            lastError = nil
        } catch {
            setError(error.localizedDescription)
        }
    }
    
    func searchMovies(query: String) async -> [TMDBMovie] {
        guard let url = URL(string: "\(baseURL)/tmdb/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            return []
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return []
            }
            
            let result = try decoder.decode(TMDBSearchResult.self, from: data)
            return result.results
        } catch {
            return []
        }
    }
    
    func addMovie(tmdbId: Int, recommender: String) async -> Movie? {
        guard let url = URL(string: "\(baseURL)/movies") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "tmdb_id": tmdbId,
            "recommender": recommender
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            
            return try decoder.decode(Movie.self, from: data)
        } catch {
            return nil
        }
    }
    
    func updateMovie(id: Int, rating: Int?, status: String?) async {
        guard let url = URL(string: "\(baseURL)/movies/\(id)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let rating = rating {
            body["my_rating"] = rating
        }
        if let status = status {
            body["status"] = status
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await session.data(for: request)
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - People

    func fetchPeople() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/people") else {
            setError("Invalid URL")
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                setError("Bad response")
                return
            }

            people = try decoder.decode([Person].self, from: data)
            lastError = nil
        } catch {
            setError(error.localizedDescription)
        }
    }
    
    func updatePerson(name: String, isTrusted: Bool) async {
        guard let url = URL(string: "\(baseURL)/people/\(name)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["is_trusted": isTrusted]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await session.data(for: request)
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func setError(_ msg: String) {
        lastError = msg
    }
}

// MARK: - API Models

struct Movie: Codable, Identifiable, Hashable {
    let id: Int
    let tmdbId: Int
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
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

struct Recommendation: Codable, Hashable {
    let recommender: String
    let dateRecommended: String
}

struct Person: Codable, Identifiable, Hashable {
    let name: String
    let isTrusted: Bool
    let movieCount: Int
    
    var id: String { name }
}

struct TMDBMovie: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let posterPath: String?
    let overview: String?
    let releaseDate: String?
    let voteAverage: Double?
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

struct TMDBSearchResult: Codable {
    let results: [TMDBMovie]
}
