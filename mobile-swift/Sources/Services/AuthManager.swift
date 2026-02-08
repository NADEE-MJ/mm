import Foundation
import Security

// MARK: - Auth Manager
// JWT token auth with Keychain storage.
// Handles login, register, logout, and token verification.

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var user: AuthUser?
    private(set) var token: String?
    private(set) var isLoading = false
    private(set) var error: String?

    var isAuthenticated: Bool { token != nil && user != nil }

    private let session = URLSession.shared
    private let baseURL: String

    private init() {
        let infoURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        baseURL = infoURL ?? "http://localhost:8000/api"

        // Load saved auth from Keychain
        if let saved = KeychainHelper.load(key: "auth_token") {
            token = saved
        }
        if let userData = KeychainHelper.loadData(key: "auth_user"),
           let decoded = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            user = decoded
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let body = LoginRequest(email: email, password: password)
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            error = "Invalid URL"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                error = "Invalid response"
                return false
            }

            if http.statusCode != 200 {
                if let errResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    error = errResponse.detail
                } else {
                    error = "Login failed"
                }
                return false
            }

            guard let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
                error = "Invalid response format"
                return false
            }

            // Fetch user info with the new token
            guard let fetchedUser = await fetchMe(token: tokenResponse.accessToken) else {
                error = "Failed to get user info"
                return false
            }

            // Save to Keychain
            token = tokenResponse.accessToken
            user = fetchedUser
            KeychainHelper.save(key: "auth_token", value: tokenResponse.accessToken)
            if let userData = try? JSONEncoder().encode(fetchedUser) {
                KeychainHelper.saveData(key: "auth_user", data: userData)
            }

            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Register

    func register(email: String, username: String, password: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let body = RegisterRequest(email: email, username: username, password: password)
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            error = "Invalid URL"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                error = "Invalid response"
                return false
            }

            if http.statusCode != 200 {
                if let errResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    error = errResponse.detail
                } else {
                    error = "Registration failed"
                }
                return false
            }

            // Auto-login after registration
            isLoading = false
            return await login(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Verify Token

    func verifyToken() async {
        guard let token else { return }
        guard let fetchedUser = await fetchMe(token: token) else {
            // Token is invalid, clear auth
            logout()
            return
        }
        user = fetchedUser
    }

    // MARK: - Logout

    func logout() {
        token = nil
        user = nil
        error = nil
        KeychainHelper.delete(key: "auth_token")
        KeychainHelper.delete(key: "auth_user")
    }

    func clearError() {
        error = nil
    }

    // MARK: - Helpers

    private func fetchMe(token: String) async -> AuthUser? {
        guard let url = URL(string: "\(baseURL)/auth/me") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try? JSONDecoder().decode(AuthUser.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Auth Models

struct AuthUser: Codable, Hashable {
    let id: String
    let email: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case id, email, username
    }
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct RegisterRequest: Encodable {
    let email: String
    let username: String
    let password: String
}

private struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct ErrorResponse: Decodable {
    let detail: String
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        saveData(key: key, data: data)
    }

    static func saveData(key: String, data: Data) {
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
