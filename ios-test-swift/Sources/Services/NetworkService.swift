import Foundation

// MARK: - Network Service
// Demonstrates URLSession GET requests against the public GitHub REST API.
// No authentication required for the endpoints used here.

@MainActor
@Observable
final class NetworkService {
    static let shared = NetworkService()

    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var fetchedUser: GitHubUser?
    private(set) var fetchedRepos: [GitHubRepo] = []

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Fetch User Profile

    func fetchUser(_ username: String) async {
        isLoading = true
        defer { isLoading = false }

        let urlString = "https://api.github.com/users/\(username)"
        guard let url = URL(string: urlString) else {
            setError("Invalid URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                setError("Not an HTTP response")
                return
            }
            guard http.statusCode == 200 else {
                setError("HTTP \(http.statusCode)")
                return
            }

            let user = try decoder.decode(GitHubUser.self, from: data)
            fetchedUser = user
            lastError = nil
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Repos

    func fetchRepos(_ username: String) async {
        isLoading = true
        defer { isLoading = false }

        let urlString = "https://api.github.com/users/\(username)/repos?sort=updated&per_page=10"
        guard let url = URL(string: urlString) else {
            setError("Invalid URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                setError("Bad response")
                return
            }

            let repos = try decoder.decode([GitHubRepo].self, from: data)
            fetchedRepos = repos
            lastError = nil
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func setLoading(_ value: Bool) {
        isLoading = value
    }

    private func setError(_ msg: String) {
        lastError = msg
    }
}

// MARK: - GitHub API Models

struct GitHubUser: Codable, Hashable {
    let login: String
    let id: Int
    let avatarUrl: String
    let name: String?
    let bio: String?
    let publicRepos: Int
    let followers: Int
    let following: Int
}

struct GitHubRepo: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let htmlUrl: String
}
