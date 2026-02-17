import LocalAuthentication
import SwiftUI

// MARK: - Biometric Auth Manager
// Uses LAContext to authenticate via Face ID / Touch ID / Optic ID.
// Can be enabled/disabled via Settings. On by default.

@MainActor
@Observable
final class BiometricAuthManager {
    var isUnlocked = false
    var authError: String?

    private(set) var biometryType: LABiometryType = .none

    // Face ID enabled by default, toggleable in Settings
    @ObservationIgnored
    @AppStorage("faceIDEnabled") var isBiometricEnabled = true

    init() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
        }

        // If biometric is disabled, auto-unlock
        if !UserDefaults.standard.bool(forKey: "faceIDEnabled"),
           UserDefaults.standard.object(forKey: "faceIDEnabled") != nil {
            isUnlocked = true
        }
    }

    var biometryLabel: String {
        switch biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.fill"
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate() {
        guard isBiometricEnabled else {
            isUnlocked = true
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        ) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        context.evaluatePolicy(policy, localizedReason: "Unlock Movie Manager") { success, authenticationError in
            Task { @MainActor in
                if success {
                    withAnimation(.spring(duration: 0.4)) {
                        self.isUnlocked = true
                    }
                    self.authError = nil
                } else {
                    self.authError = authenticationError?.localizedDescription
                }
            }
        }
    }

    func setBiometricEnabled(_ enabled: Bool) {
        isBiometricEnabled = enabled
        if !enabled {
            isUnlocked = true
        }
    }
}
