import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var token: String?
    @Published var currentUser: UserProfile?

    private let tokenKey = "gymbo_token"
    private let userKey = "gymbo_user"

    private init() {
        token = UserDefaults.standard.string(forKey: tokenKey)
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            currentUser = user
        }
    }

    var isAuthenticated: Bool { token != nil && currentUser != nil }

    func login(email: String, password: String) async throws {
        let response = try await NetworkService.shared.login(email: email, password: password)
        token = response.accessToken
        currentUser = response.user
        persist()
    }

    func verifyToken() async {
        guard token != nil else { return }
        do {
            let profile = try await NetworkService.shared.verifyToken()
            currentUser = profile
            persist()
        } catch {
            if let urlError = error as? URLError {
                // Keep existing session when offline; repository can continue local-first mode.
                AppLog.info("Token verification deferred: \(urlError.localizedDescription)", category: .auth)
                return
            }

            let message = error.localizedDescription.lowercased()
            if message.contains("401") || message.contains("403") || message.contains("authentication") {
                logout()
            }
        }
    }

    func updateProfile(unitPreference: String, barbellWeight: Double) async throws {
        let profile = try await NetworkService.shared.updateProfile(unitPreference: unitPreference, barbellWeight: barbellWeight)
        currentUser = profile
        persist()
    }

    func logout() {
        token = nil
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    private func persist() {
        UserDefaults.standard.setValue(token, forKey: tokenKey)
        if let currentUser, let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.setValue(data, forKey: userKey)
        }
    }
}

struct UserProfile: Codable {
    var id: String
    var email: String
    var username: String
    var unitPreference: String
    var barbellWeight: Double

    enum CodingKeys: String, CodingKey {
        case id, email, username
        case unitPreference = "unit_preference"
        case barbellWeight = "barbell_weight"
    }
}

struct LoginEnvelope: Codable {
    var accessToken: String
    var tokenType: String
    var user: UserProfile

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}
