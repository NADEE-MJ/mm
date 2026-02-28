import LocalAuthentication
import SwiftUI

@MainActor
@Observable
final class BiometricAuthManager {
    var isUnlocked = false
    var authError: String?
    var isPrompting = false

    private(set) var biometryType: LABiometryType = .none

    init() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
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

    func lock() {
        isUnlocked = false
    }

    func authenticate(reason: String) {
        guard !isPrompting else { return }

        isPrompting = true
        authError = nil

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
            Task { @MainActor in
                self.isPrompting = false
                if success {
                    self.isUnlocked = true
                    self.authError = nil
                } else {
                    self.isUnlocked = false
                    self.authError = evalError?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}
