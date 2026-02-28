import SwiftUI

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private let deviceIdKey = "server_pilot_device_id"

    var deviceId: String?

    var isEnrolled: Bool {
        deviceId != nil
    }

    private init() {
        deviceId = UserDefaults.standard.string(forKey: deviceIdKey)
    }

    func setDeviceId(_ id: String) {
        deviceId = id
        UserDefaults.standard.set(id, forKey: deviceIdKey)
    }

    func clearEnrollment() {
        deviceId = nil
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
    }
}
