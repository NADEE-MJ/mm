import CryptoKit
import Foundation
import Security

enum KeyKind: String {
    case keyA
    case keyB

    var tagData: Data {
        "com.nadeem.serverpilot.\(rawValue)".data(using: .utf8) ?? Data()
    }
}

struct SignedRequestHeaders {
    let timestamp: String
    let nonce: String
    let keyType: String
    let signatureBase64: String
    let bodyHash: String
}

enum DeviceKeyError: Error {
    case keyCreationFailed
    case keyNotFound
    case signatureFailed
    case publicKeyExportFailed
}

final class DeviceKeyManager {
    nonisolated(unsafe) static let shared = DeviceKeyManager()

    private init() {}

    func ensureKeysExist() throws {
        _ = try privateKey(for: .keyA, prompt: nil)
        _ = try privateKey(for: .keyB, prompt: "Authorize ServerPilot destructive actions")
    }

    func exportPublicKeyPEM(for keyKind: KeyKind) throws -> String {
        let privateKey = try privateKey(
            for: keyKind,
            prompt: keyKind == .keyB ? "Authorize key export" : nil
        )

        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else {
            throw DeviceKeyError.publicKeyExportFailed
        }

        // Wrap ANSI X9.63 key bytes in a P-256 SPKI ASN.1 header.
        // This yields a PEM that Bun crypto.subtle.importKey("spki", ...) can consume.
        let spkiPrefix = Data([
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02,
            0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
            0x42, 0x00,
        ])

        let spkiData = spkiPrefix + publicKeyData
        let base64 = spkiData.base64EncodedString()
        let lines = stride(from: 0, to: base64.count, by: 64).map { start in
            let startIndex = base64.index(base64.startIndex, offsetBy: start)
            let endIndex = base64.index(startIndex, offsetBy: min(64, base64.count - start))
            return String(base64[startIndex..<endIndex])
        }

        return "-----BEGIN PUBLIC KEY-----\n\(lines.joined(separator: "\n"))\n-----END PUBLIC KEY-----"
    }

    func signRequest(
        deviceId: String,
        method: String,
        url: URL,
        bodyData: Data,
        destructive: Bool
    ) throws -> SignedRequestHeaders {
        let keyKind: KeyKind = destructive ? .keyB : .keyA

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString.lowercased()
        let host = url.host ?? ""
        let pathAndQuery = wirePathAndQuery(url)
        let bodyHash = sha256Hex(bodyData)

        let signingInput = "\(timestamp):\(nonce):\(method.uppercased()):\(host):\(pathAndQuery):\(bodyHash)"
        let messageData = Data(signingInput.utf8)

        let key = try privateKey(
            for: keyKind,
            prompt: destructive ? "Authorize destructive action" : nil
        )

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .ecdsaSignatureMessageX962SHA256,
            messageData as CFData,
            &error
        ) as Data?
        else {
            throw error?.takeRetainedValue() ?? DeviceKeyError.signatureFailed
        }

        return SignedRequestHeaders(
            timestamp: timestamp,
            nonce: nonce,
            keyType: destructive ? "B" : "A",
            signatureBase64: signature.base64EncodedString(),
            bodyHash: bodyHash
        )
    }

    private func wirePathAndQuery(_ url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path
        }

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery, !query.isEmpty {
            return "\(path)?\(query)"
        }

        return path
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func privateKey(for keyKind: KeyKind, prompt: String?) throws -> SecKey {
        if let key = try? fetchKey(for: keyKind, prompt: prompt) {
            return key
        }

        try createKey(for: keyKind)
        return try fetchKey(for: keyKind, prompt: prompt)
    }

    private func fetchKey(for keyKind: KeyKind, prompt: String?) throws -> SecKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyKind.tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]

        if let prompt {
            query[kSecUseOperationPrompt as String] = prompt
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let item else {
            throw DeviceKeyError.keyNotFound
        }

        let key = item as! SecKey
        return key
    }

    private func createKey(for keyKind: KeyKind) throws {
        let flags: SecAccessControlCreateFlags = keyKind == .keyB
            ? [.privateKeyUsage, .biometryCurrentSet]
            : [.privateKeyUsage]

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            &error
        ) else {
            throw error?.takeRetainedValue() ?? DeviceKeyError.keyCreationFailed
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyKind.tagData,
                kSecAttrAccessControl as String: access,
            ],
        ]

        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            throw error?.takeRetainedValue() ?? DeviceKeyError.keyCreationFailed
        }
    }
}
