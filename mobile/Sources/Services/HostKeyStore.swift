import CryptoKit
import Foundation
import Security

// MARK: - Error types

enum HostKeyError: LocalizedError {
    case fingerprintMismatch(expected: String, got: String)
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .fingerprintMismatch(let expected, let got):
            return """
            SSH host key fingerprint mismatch!
            Expected: \(expected)
            Got:      \(got)
            The server's identity may have changed. Do not connect until you verify.
            """
        case .keychainError(let status):
            return "Keychain error storing host key: \(status)"
        }
    }
}

// MARK: - HostKeyStore

/// Trust-on-first-use SSH host key store.
///
/// On first connection to a host, records the SHA-256 fingerprint of its public
/// key in the Keychain. On subsequent connections, rejects if the fingerprint
/// has changed. Fingerprints are stored independently per host IP so that the
/// local LAN and Tailscale IPs are each verified independently.
final class HostKeyStore {
    nonisolated(unsafe) static let shared = HostKeyStore()

    private static let keychainService = "com.nadeem.mentat.hostkeys"

    private init() {}

    // MARK: - Public API

    /// Verify or record the host key for the given host identifier.
    ///
    /// - Parameters:
    ///   - hostKey: The raw bytes of the server's public key as received during
    ///              the SSH handshake.
    ///   - host: An identifier for the host (e.g. "192.168.1.10" or "100.x.y.z").
    /// - Throws: `HostKeyError.fingerprintMismatch` if the stored fingerprint
    ///   does not match. The caller should surface this to the user.
    func verify(hostKey: Data, for host: String) throws {
        let fingerprint = sha256Fingerprint(hostKey)
        if let stored = storedFingerprint(for: host) {
            guard stored == fingerprint else {
                throw HostKeyError.fingerprintMismatch(expected: stored, got: fingerprint)
            }
        } else {
            try storeFingerprint(fingerprint, for: host)
        }
    }

    /// Returns the stored fingerprint for the given host, or nil if not yet trusted.
    func fingerprint(for host: String) -> String? {
        storedFingerprint(for: host)
    }

    /// Remove the stored fingerprint for the given host (e.g. to reset trust).
    func removeFingerprint(for host: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: host,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private helpers

    private func sha256Fingerprint(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined(separator: ":")
        return "SHA256:\(hex)"
    }

    private func storedFingerprint(for host: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: host,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    private func storeFingerprint(_ fingerprint: String, for host: String) throws {
        guard let data = fingerprint.data(using: .utf8) else {
            throw HostKeyError.keychainError(errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: host,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            if insertStatus != errSecSuccess {
                throw HostKeyError.keychainError(insertStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw HostKeyError.keychainError(updateStatus)
        }
    }
}
