import LocalAuthentication
import SwiftUI

// MARK: - Biometric Auth Manager
// Uses LAContext to authenticate via Face ID / Touch ID / Optic ID.
// The app stays blurred until authentication succeeds.

@MainActor
@Observable
final class BiometricAuthManager {
    var isUnlocked = false
    var authError: String?

    private(set) var biometryType: LABiometryType = .none

    init() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
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

    func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        var error: NSError?
        // Try biometrics first, fall back to device passcode
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
}
