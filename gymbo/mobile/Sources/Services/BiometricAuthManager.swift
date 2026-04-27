import Foundation
import LocalAuthentication

@MainActor
final class BiometricAuthManager: ObservableObject {
    @Published var isUnlocked = true
    @Published var authError: String?

    var biometryLabel: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    var biometryIcon: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isUnlocked = true
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Gymbo") { [weak self] success, evaluateError in
            Task { @MainActor in
                if success {
                    self?.isUnlocked = true
                    self?.authError = nil
                } else {
                    self?.isUnlocked = false
                    self?.authError = evaluateError?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}
