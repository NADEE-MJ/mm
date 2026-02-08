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
        baseURL = infoURL ?? "https://localhost:8000/api"
        
        // Debug: Log the configured API base URL
        print("🔧 [AuthManager] Initialized with baseURL: \(baseURL)")
        print("🔧 [AuthManager] Info.plist API_BASE_URL: \(infoURL ?? "nil (using fallback)")")

        // Load saved auth from Keychain
        if let saved = KeychainHelper.load(key: "auth_token") {
            token = saved
            print("🔧 [AuthManager] Loaded saved token from Keychain")
        }
        if let userData = KeychainHelper.loadData(key: "auth_user"),
           let decoded = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            user = decoded
            print("🔧 [AuthManager] Loaded saved user from Keychain: \(decoded.email)")
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let body = LoginRequest(email: email, password: password)
        let urlString = "\(baseURL)/auth/login"
        
        print("\n🔐 [LOGIN] Starting login attempt")
        print("🔐 [LOGIN] Base URL: \(baseURL)")
        print("🔐 [LOGIN] Full URL: \(urlString)")
        print("🔐 [LOGIN] Email: \(email)")
        
        guard let url = URL(string: urlString) else {
            let errorMsg = "❌ Invalid URL: \(urlString)"
            print("🔐 [LOGIN] \(errorMsg)")
            error = "Invalid URL - Check: \(urlString)"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        
        print("🔐 [LOGIN] Request method: POST")
        print("🔐 [LOGIN] Request headers: \(request.allHTTPHeaderFields ?? [:])")

        do {
            print("🔐 [LOGIN] Sending request...")
            let startTime = Date()
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            print("🔐 [LOGIN] Response received in \(String(format: "%.2f", duration))s")
            
            guard let http = response as? HTTPURLResponse else {
                let errorMsg = "❌ Invalid response type"
                print("🔐 [LOGIN] \(errorMsg)")
                error = "Invalid response - Not HTTP response"
                return false
            }

            print("🔐 [LOGIN] HTTP Status: \(http.statusCode)")
            print("🔐 [LOGIN] Response headers: \(http.allHeaderFields)")
            
            if let dataString = String(data: data, encoding: .utf8) {
                print("🔐 [LOGIN] Response body: \(dataString)")
            }

            if http.statusCode != 200 {
                var errorMsg = "Login failed (HTTP \(http.statusCode))"
                if let errResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    errorMsg = "\(errResponse.detail) (HTTP \(http.statusCode))"
                    print("🔐 [LOGIN] ❌ Server error: \(errResponse.detail)")
                } else if let dataString = String(data: data, encoding: .utf8) {
                    print("🔐 [LOGIN] ❌ Raw error: \(dataString)")
                    errorMsg = "Login failed: \(dataString.prefix(100))"
                }
                error = errorMsg
                return false
            }

            guard let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
                let errorMsg = "❌ Invalid response format - couldn't decode token"
                print("🔐 [LOGIN] \(errorMsg)")
                error = "Invalid response format from server"
                return false
            }

            print("🔐 [LOGIN] ✅ Token received successfully")

            // Fetch user info with the new token
            guard let fetchedUser = await fetchMe(token: tokenResponse.accessToken) else {
                let errorMsg = "❌ Failed to fetch user info"
                print("🔐 [LOGIN] \(errorMsg)")
                error = "Failed to get user info from server"
                return false
            }

            print("🔐 [LOGIN] ✅ User info retrieved: \(fetchedUser.email)")

            // Save to Keychain
            token = tokenResponse.accessToken
            user = fetchedUser
            KeychainHelper.save(key: "auth_token", value: tokenResponse.accessToken)
            if let userData = try? JSONEncoder().encode(fetchedUser) {
                KeychainHelper.saveData(key: "auth_user", data: userData)
            }

            print("🔐 [LOGIN] ✅ Login successful!\n")
            return true
        } catch let urlError as URLError {
            let errorMsg = "Network error: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))"
            print("🔐 [LOGIN] ❌ URLError: \(errorMsg)")
            print("🔐 [LOGIN] ❌ URLError details: \(urlError)")
            
            // Provide more specific error messages
            var detailedError = errorMsg
            switch urlError.code {
            case .notConnectedToInternet:
                detailedError = "No internet connection"
            case .cannotFindHost:
                detailedError = "Cannot find host: \(urlString) - Check DNS/URL"
            case .cannotConnectToHost:
                detailedError = "Cannot connect to: \(urlString) - Server down?"
            case .timedOut:
                detailedError = "Connection timed out to: \(urlString)"
            case .secureConnectionFailed:
                detailedError = "HTTPS/SSL failed for: \(urlString) - Check certificate"
            case .serverCertificateUntrusted:
                detailedError = "Server certificate not trusted: \(urlString)"
            default:
                detailedError = "\(errorMsg)\nURL: \(urlString)"
            }
            
            self.error = detailedError
            return false
        } catch {
            let errorMsg = "Unexpected error: \(error.localizedDescription)"
            print("🔐 [LOGIN] ❌ \(errorMsg)")
            print("🔐 [LOGIN] ❌ Error details: \(error)")
            self.error = "\(errorMsg)\nURL: \(urlString)"
            return false
        }
    }

    // MARK: - Register

    func register(email: String, username: String, password: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let body = RegisterRequest(email: email, username: username, password: password)
        let urlString = "\(baseURL)/auth/register"
        
        print("\n📝 [REGISTER] Starting registration attempt")
        print("📝 [REGISTER] Base URL: \(baseURL)")
        print("📝 [REGISTER] Full URL: \(urlString)")
        print("📝 [REGISTER] Email: \(email), Username: \(username)")
        
        guard let url = URL(string: urlString) else {
            let errorMsg = "❌ Invalid URL: \(urlString)"
            print("📝 [REGISTER] \(errorMsg)")
            error = "Invalid URL - Check: \(urlString)"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            print("📝 [REGISTER] Sending request...")
            let (data, response) = try await session.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                print("📝 [REGISTER] ❌ Invalid response type")
                error = "Invalid response"
                return false
            }

            print("📝 [REGISTER] HTTP Status: \(http.statusCode)")

            if http.statusCode != 200 {
                var errorMsg = "Registration failed (HTTP \(http.statusCode))"
                if let errResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    errorMsg = "\(errResponse.detail) (HTTP \(http.statusCode))"
                    print("📝 [REGISTER] ❌ Server error: \(errResponse.detail)")
                } else if let dataString = String(data: data, encoding: .utf8) {
                    print("📝 [REGISTER] ❌ Raw error: \(dataString)")
                }
                error = errorMsg
                return false
            }

            print("📝 [REGISTER] ✅ Registration successful, now logging in...")
            
            // Auto-login after registration
            isLoading = false
            return await login(email: email, password: password)
        } catch let urlError as URLError {
            let errorMsg = "Network error: \(urlError.localizedDescription)"
            print("📝 [REGISTER] ❌ URLError: \(errorMsg)")
            self.error = "\(errorMsg)\nURL: \(urlString)"
            return false
        } catch {
            let errorMsg = "Unexpected error: \(error.localizedDescription)"
            print("📝 [REGISTER] ❌ \(errorMsg)")
            self.error = "\(errorMsg)\nURL: \(urlString)"
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
        let urlString = "\(baseURL)/auth/me"
        print("👤 [FETCH_ME] Fetching user info from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("👤 [FETCH_ME] ❌ Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("👤 [FETCH_ME] ❌ Invalid response type")
                return nil
            }
            
            print("👤 [FETCH_ME] HTTP Status: \(http.statusCode)")
            
            if http.statusCode != 200 {
                if let dataString = String(data: data, encoding: .utf8) {
                    print("👤 [FETCH_ME] ❌ Error response: \(dataString)")
                }
                return nil
            }
            
            let user = try? JSONDecoder().decode(AuthUser.self, from: data)
            if let user = user {
                print("👤 [FETCH_ME] ✅ Successfully fetched user: \(user.email)")
            } else {
                print("👤 [FETCH_ME] ❌ Failed to decode user data")
            }
            return user
        } catch let urlError as URLError {
            print("👤 [FETCH_ME] ❌ URLError: \(urlError.localizedDescription)")
            return nil
        } catch {
            print("👤 [FETCH_ME] ❌ Error: \(error.localizedDescription)")
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
