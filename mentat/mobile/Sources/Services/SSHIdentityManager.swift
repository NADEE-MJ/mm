import CryptoKit
import Foundation
import Security

// MARK: - Error types

enum SSHIdentityError: LocalizedError {
    case keyCreationFailed
    case keyNotFound
    case publicKeyExportFailed

    var errorDescription: String? {
        switch self {
        case .keyCreationFailed:
            return "Failed to create SSH identity key."
        case .keyNotFound:
            return "SSH identity key not found."
        case .publicKeyExportFailed:
            return "Failed to export SSH public key."
        }
    }
}

// MARK: - SSHIdentityManager

/// Manages the P-256 ECDSA key pair used as the SSH client identity.
///
/// The private key lives in the Secure Enclave under
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` with no biometric constraint
/// on the key itself (biometrics are applied per-request in NetworkService for
/// mutating operations, not at the key-access level).
///
/// The public key is exported in OpenSSH ecdsa-sha2-nistp256 wire format so the
/// user can paste it directly into `~/.ssh/authorized_keys` on the server.
///
/// Key storage: The `SecureEnclave.P256.Signing.PrivateKey` is created once and
/// the Keychain item stores a dummy sentinel (the key itself lives in the SE).
/// We recover it by re-creating it with the stored `dataRepresentation` on
/// subsequent launches via `SecureEnclave.P256.Signing.PrivateKey(dataRepresentation:)`.
final class SSHIdentityManager {
    nonisolated(unsafe) static let shared = SSHIdentityManager()

    private static let keyTag = "com.nadeem.mentat.sshIdentity"
    private static let tagData: Data = Data(keyTag.utf8)

    private init() {}

    // MARK: - Lifecycle

    /// Ensure the key exists, creating it on first launch.
    func ensureKeyExists() throws {
        _ = try getOrCreateKey()
    }

    /// Delete the identity key from the Secure Enclave (e.g. on reset).
    func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.tagData,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Key access

    /// Returns the existing Secure Enclave key or creates one on first call.
    /// The key is cached in the Keychain as a `dataRepresentation` blob so it
    /// can be recovered across app launches.
    func getOrCreateKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        if let existing = try? loadKey() {
            return existing
        }
        return try createAndStoreKey()
    }

    // MARK: - Public key export (OpenSSH wire format)

    /// Returns the public key in OpenSSH `ecdsa-sha2-nistp256` wire format,
    /// suitable for appending to `~/.ssh/authorized_keys`.
    ///
    /// Wire format (each field is big-endian uint32 length-prefixed):
    ///   string   "ecdsa-sha2-nistp256"
    ///   string   "nistp256"
    ///   string   <uncompressed EC point: 0x04 || X || Y>
    func exportOpenSSHPublicKey() throws -> String {
        let privateKey = try getOrCreateKey()
        let publicKey = privateKey.publicKey

        // CryptoKit P256.Signing.PublicKey.x963Representation is the uncompressed
        // ANSI X9.63 point: 0x04 || X (32 bytes) || Y (32 bytes) = 65 bytes.
        let rawData = publicKey.x963Representation
        guard rawData.count == 65, rawData[0] == 0x04 else {
            throw SSHIdentityError.publicKeyExportFailed
        }

        let keyTypeStr = "ecdsa-sha2-nistp256"
        let curveStr = "nistp256"

        var wireData = Data()
        wireData.append(sshString(keyTypeStr))
        wireData.append(sshString(curveStr))
        wireData.append(sshBytes(rawData))

        let base64 = wireData.base64EncodedString()
        return "ecdsa-sha2-nistp256 \(base64) mentat-ios"
    }

    // MARK: - Private helpers

    private func loadKey() throws -> SecureEnclave.P256.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.tagData,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        // Re-hydrate the SecureEnclave key from its opaque data representation.
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
    }

    private func createAndStoreKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        )

        let key: SecureEnclave.P256.Signing.PrivateKey
        guard let accessControl = access else {
            throw SSHIdentityError.keyCreationFailed
        }
        key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: accessControl)

        // Persist the opaque `dataRepresentation` (not raw key material) so we
        // can recover the key on future launches.
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.tagData,
            kSecValueData as String: key.dataRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw SSHIdentityError.keyCreationFailed
        }

        return key
    }

    // MARK: - OpenSSH wire-format helpers

    /// Encode a string as an SSH wire-format string: uint32 length || UTF-8 bytes.
    private func sshString(_ value: String) -> Data {
        sshBytes(Data(value.utf8))
    }

    /// Encode raw bytes as an SSH wire-format string: uint32 length || bytes.
    private func sshBytes(_ bytes: Data) -> Data {
        var result = Data()
        var length = UInt32(bytes.count).bigEndian
        result.append(Data(bytes: &length, count: 4))
        result.append(bytes)
        return result
    }
}
