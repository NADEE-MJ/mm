import Foundation

/// Stores and retrieves SSH connection configuration.
///
/// Values are persisted to UserDefaults (non-sensitive) with the exception
/// of the SSH username which is stored there too (not secret). The only
/// truly sensitive material is managed by SSHIdentityManager (Secure Enclave).
@MainActor
@Observable
final class SSHConfigManager {
    static let shared = SSHConfigManager()

    // MARK: - Configuration

    var localIP: String {
        didSet { UserDefaults.standard.set(localIP, forKey: Keys.localIP) }
    }

    var tailscaleIP: String {
        didSet { UserDefaults.standard.set(tailscaleIP, forKey: Keys.tailscaleIP) }
    }

    var sshUsername: String {
        didSet { UserDefaults.standard.set(sshUsername, forKey: Keys.sshUsername) }
    }

    var sshPort: Int {
        didSet { UserDefaults.standard.set(sshPort, forKey: Keys.sshPort) }
    }

    var apiPort: Int {
        didSet { UserDefaults.standard.set(apiPort, forKey: Keys.apiPort) }
    }

    // MARK: - Derived state

    /// True when at least one IP and all other required fields are filled in.
    var isConfigured: Bool {
        (!localIP.isEmpty || !tailscaleIP.isEmpty)
            && !sshUsername.isEmpty
            && sshPort > 0
            && apiPort > 0
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        localIP      = defaults.string(forKey: Keys.localIP)      ?? ""
        tailscaleIP  = defaults.string(forKey: Keys.tailscaleIP)  ?? ""
        sshUsername  = defaults.string(forKey: Keys.sshUsername)  ?? ""
        sshPort      = defaults.integer(forKey: Keys.sshPort) > 0
                           ? defaults.integer(forKey: Keys.sshPort)
                           : 22
        apiPort      = defaults.integer(forKey: Keys.apiPort) > 0
                           ? defaults.integer(forKey: Keys.apiPort)
                           : 4310
    }

    // MARK: - Actions

    /// Clears all stored configuration and resets to defaults.
    func clearConfiguration() {
        localIP     = ""
        tailscaleIP = ""
        sshUsername = ""
        sshPort     = 22
        apiPort     = 4310
    }

    // MARK: - Keys

    private enum Keys {
        static let localIP     = "ssh_local_ip"
        static let tailscaleIP = "ssh_tailscale_ip"
        static let sshUsername = "ssh_username"
        static let sshPort     = "ssh_port"
        static let apiPort     = "ssh_api_port"
    }
}
