import Foundation
import NIOCore
import NIOPosix
import NIOSSH

// MARK: - Connection state

enum SSHConnectionState: Equatable {
    case disconnected
    case connecting
    case connectedLocal
    case connectedTailscale
}

// MARK: - Connection error

enum SSHConnectionError: LocalizedError {
    case notConfigured
    case hostKeyRejected(String)
    case authenticationFailed
    case tunnelFailed(String)
    case bothAddressesFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SSH connection is not configured. Please complete setup."
        case .hostKeyRejected(let reason):
            return reason
        case .authenticationFailed:
            return "SSH authentication failed. Ensure the public key is in authorized_keys."
        case .tunnelFailed(let reason):
            return "SSH tunnel failed: \(reason)"
        case .bothAddressesFailed:
            return "Could not connect via local IP or Tailscale IP."
        }
    }
}

// MARK: - SSHConnectionManager

/// Manages a persistent SSH tunnel to the Mentat backend server.
///
/// Connection strategy:
/// 1. Try the local LAN IP first (2-second timeout).
/// 2. If that fails, fall back to the Tailscale IP.
/// 3. Once connected, open a local port-forward tunnel to
///    127.0.0.1:<API_PORT> on the server.
/// 4. All HTTP traffic from NetworkService flows through this local port.
/// 5. Reconnects on drop with exponential backoff (1s → 2s → 4s … 60s cap).
///
/// Security:
/// - Uses trust-on-first-use host key verification via HostKeyStore.
/// - The SSH client identity key is managed by SSHIdentityManager (Secure
///   Enclave P-256, no biometric on the key itself).
@MainActor
@Observable
final class SSHConnectionManager {
    // `nonisolated(unsafe)` + explicit lazy wrapper avoids calling the
    // `@MainActor`-isolated default initialiser from a nonisolated context.
    // The instance is created once on first access; all mutations thereafter
    // are guarded by the `@MainActor` annotation on the class itself.
    nonisolated(unsafe) static let shared: SSHConnectionManager = {
        MainActor.assumeIsolated { SSHConnectionManager() }
    }()

    // MARK: - Published state

    var state: SSHConnectionState = .disconnected
    var lastError: String?

    // MARK: - Tunnel endpoint (NetworkService uses this)

    /// The local port on which the SSH tunnel is listening.
    /// NetworkService should direct all requests to http://127.0.0.1:<tunnelPort>.
    ///
    /// Marked `nonisolated(unsafe)` so that non-actor-isolated callers (e.g.
    /// WebSocketManager) can read the port without hopping to the main actor.
    /// Reads are safe: `Int` is trivially copyable and the worst case is 0
    /// (tunnel not yet connected).
    nonisolated(unsafe) private(set) var tunnelPort: Int = 0

    // MARK: - Private

    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private var tunnelChannel: Channel?
    private var reconnectTask: Task<Void, Never>?
    private var backoffSeconds: Double = 1

    private init() {}

    // MARK: - Public API

    /// Start the SSH tunnel. Connects and schedules reconnects automatically.
    func start() {
        guard reconnectTask == nil else { return }
        scheduleConnect()
    }

    /// Disconnect and stop reconnecting.
    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        closeChannels()
        state = .disconnected
    }

    // MARK: - Connection logic

    private func scheduleConnect() {
        reconnectTask = Task {
            await connectLoop()
        }
    }

    private func connectLoop() async {
        while !Task.isCancelled {
            state = .connecting
            lastError = nil

            let config = SSHConfigManager.shared

            guard config.isConfigured else {
                state = .disconnected
                lastError = SSHConnectionError.notConfigured.localizedDescription
                return
            }

            do {
                try await attemptConnection(config: config)
                backoffSeconds = 1

                // Connection dropped — reconnect
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } catch let error as SSHConnectionError {
                state = .disconnected
                lastError = error.localizedDescription
                AppLog.error("SSH connection error: \(error.localizedDescription)")

                // For host key rejections, do not retry automatically —
                // require user intervention.
                if case .hostKeyRejected = error {
                    return
                }
            } catch {
                state = .disconnected
                lastError = error.localizedDescription
                AppLog.error("SSH error: \(error.localizedDescription)")
            }

            if !Task.isCancelled {
                let sleepNs = UInt64(min(backoffSeconds, 60) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNs)
                backoffSeconds = min(backoffSeconds * 2, 60)
            }
        }
    }

    private func attemptConnection(config: SSHConfigManager) async throws {
        // Try local LAN IP first with a short 2-second timeout, then fall back.
        if !config.localIP.isEmpty {
            do {
                try await connect(
                    host: config.localIP,
                    port: config.sshPort,
                    username: config.sshUsername,
                    apiPort: config.apiPort,
                    connectionKind: .local
                )
                return
            } catch let error as SSHConnectionError {
                if case .hostKeyRejected = error { throw error }
                AppLog.info("Local IP connection failed, trying Tailscale: \(error.localizedDescription)")
            } catch {
                AppLog.info("Local IP connection failed, trying Tailscale: \(error.localizedDescription)")
            }
        }

        if !config.tailscaleIP.isEmpty {
            try await connect(
                host: config.tailscaleIP,
                port: config.sshPort,
                username: config.sshUsername,
                apiPort: config.apiPort,
                connectionKind: .tailscale
            )
        } else {
            throw SSHConnectionError.bothAddressesFailed
        }
    }

    private func connect(
        host: String,
        port: Int,
        username: String,
        apiPort: Int,
        connectionKind: ConnectionKind
    ) async throws {
        closeChannels()

        let identityManager = SSHIdentityManager.shared
        let hostKeyStore = HostKeyStore.shared

        // Build SSH client configuration with our Secure Enclave key.
        // NIOSSHPrivateKey has a built-in initialiser for SecureEnclave keys.
        let seKey = try identityManager.getOrCreateKey()
        let clientKey = NIOSSHPrivateKey(secureEnclaveP256Key: seKey)

        let hostKeyValidator = TrustOnFirstUseDelegate(
            host: host,
            store: hostKeyStore
        )

        let sshConfig = SSHClientConfiguration(
            userAuthDelegate: PublicKeyAuthDelegate(username: username, privateKey: clientKey),
            serverAuthDelegate: hostKeyValidator
        )

        // Connect with a short timeout for the local IP attempt.
        let connectionTimeout = connectionKind == .local
            ? TimeAmount.seconds(2)
            : TimeAmount.seconds(10)

        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    NIOSSHHandler(
                        role: .client(sshConfig),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    ),
                ])
            }
            .connectTimeout(connectionTimeout)

        let serverChannel = try await bootstrap.connect(host: host, port: port).get()
        channel = serverChannel

        // Validate host key (trust on first use or reject on mismatch).
        // The TrustOnFirstUseDelegate throws during SSH handshake if there is
        // a mismatch; we re-surface it here as SSHConnectionError.
        if let hostKeyError = hostKeyValidator.error {
            throw SSHConnectionError.hostKeyRejected(hostKeyError)
        }

        // Open a TCP forwarding channel: local port → server's 127.0.0.1:apiPort.
        let localPort = try await openPortForward(
            serverChannel: serverChannel,
            remoteHost: "127.0.0.1",
            remotePort: apiPort
        )

        await MainActor.run {
            self.tunnelPort = localPort
            self.state = connectionKind == .local ? .connectedLocal : .connectedTailscale
        }

        AppLog.info("SSH tunnel active via \(connectionKind == .local ? "local" : "Tailscale") — tunnel port \(localPort)")

        // Wait until the channel closes.
        try await serverChannel.closeFuture.get()

        await MainActor.run {
            self.state = .disconnected
            self.tunnelPort = 0
        }
    }

    /// Opens a local TCP server that forwards connections through the SSH
    /// channel to `remoteHost:remotePort` on the server.
    /// Returns the local port the server is listening on.
    private func openPortForward(
        serverChannel: Channel,
        remoteHost: String,
        remotePort: Int
    ) async throws -> Int {
        let localServer = try await ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { localChannel in
                // For each inbound local connection, open an SSH forwarded channel.
                // IMPORTANT: we must return the full future chain so that
                // ServerBootstrap waits for the pipeline to be fully configured
                // before the channel begins reading. Returning early (succeeded
                // immediately) would let data arrive before the forwarding
                // handlers are installed, causing requests to be silently dropped.
                let promise = localChannel.eventLoop.makePromise(of: Channel.self)
                return serverChannel.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler -> EventLoopFuture<Void> in
                    // `SSHChannelType.DirectTCPIP` requires the originator address.
                    // Use a dummy loopback address since we're the local forwarder.
                    // SocketAddress(ipAddress:port:) throws for invalid input, but
                    // "127.0.0.1" is a compile-time constant and always valid.
                    let loopback: SocketAddress
                    do {
                        loopback = try SocketAddress(ipAddress: "127.0.0.1", port: 0)
                    } catch {
                        return localChannel.eventLoop.makeFailedFuture(
                            SSHConnectionError.tunnelFailed("Failed to create loopback address: \(error.localizedDescription)")
                        )
                    }
                    let directTCP = SSHChannelType.DirectTCPIP(
                        targetHost: remoteHost,
                        targetPort: remotePort,
                        originatorAddress: loopback
                    )
                    sshHandler.createChannel(
                        promise,
                        channelType: .directTCPIP(directTCP)
                    ) { childChannel, channelType in
                        guard case .directTCPIP = channelType else {
                            return childChannel.eventLoop.makeFailedFuture(
                                SSHConnectionError.tunnelFailed("Unexpected channel type")
                            )
                        }
                        return childChannel.pipeline.addHandlers([
                            SSHWrapperHandler(),
                            DataForwardingHandler(localChannel: localChannel),
                        ])
                    }
                    return promise.futureResult.flatMap { childChannel in
                        localChannel.pipeline.addHandlers([
                            DataForwardingHandler(localChannel: childChannel),
                        ])
                    }
                }
            }
            .bind(host: "127.0.0.1", port: 0)
            .get()

        tunnelChannel = localServer

        guard let addr = localServer.localAddress, let port = addr.port else {
            throw SSHConnectionError.tunnelFailed("Could not determine local port")
        }

        return port
    }

    private func closeChannels() {
        tunnelChannel?.close(mode: .all, promise: nil)
        channel?.close(mode: .all, promise: nil)
        tunnelChannel = nil
        channel = nil
        tunnelPort = 0
    }
}

// MARK: - Connection kind (internal)

private enum ConnectionKind {
    case local
    case tailscale
}

// MARK: - NIO SSH delegates

/// Host key validator implementing trust-on-first-use via HostKeyStore.
private final class TrustOnFirstUseDelegate: NIOSSHClientServerAuthenticationDelegate {
    private let host: String
    private let store: HostKeyStore
    private(set) var error: String?

    init(host: String, store: HostKeyStore) {
        self.host = host
        self.store = store
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        // Serialize the host key to OpenSSH wire format for stable fingerprinting.
        // String(openSSHPublicKey:) is the public API that produces a canonical
        // "algorithm base64" string from which we derive the SHA-256 fingerprint.
        do {
            let openSSHString = String(openSSHPublicKey: hostKey)
            let keyBytes = Data(openSSHString.utf8)
            try store.verify(hostKey: keyBytes, for: host)
            validationCompletePromise.succeed()
        } catch let e as HostKeyError {
            error = e.localizedDescription
            validationCompletePromise.fail(e)
        } catch {
            let msg = error.localizedDescription
            self.error = msg
            validationCompletePromise.fail(error)
        }
    }
}

/// Public key authentication delegate that uses the Secure Enclave key.
private final class PublicKeyAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let privateKey: NIOSSHPrivateKey

    init(username: String, privateKey: NIOSSHPrivateKey) {
        self.username = username
        self.privateKey = privateKey
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard availableMethods.contains(.publicKey) else {
            nextChallengePromise.succeed(nil)
            return
        }

        nextChallengePromise.succeed(
            NIOSSHUserAuthenticationOffer(
                username: username,
                serviceName: "ssh-connection",
                offer: .privateKey(.init(privateKey: privateKey))
            )
        )
    }
}

// MARK: - NIO channel handler for data forwarding

/// Wraps raw `ByteBuffer` data in `SSHChannelData` envelopes and unwraps them
/// on the way in. Required on the SSH child channel side of the forward.
private final class SSHWrapperHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let payload = unwrapInboundIn(data)
        guard case .channel = payload.type, case .byteBuffer(let buffer) = payload.data else {
            return
        }
        context.fireChannelRead(wrapInboundOut(buffer))
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let wrapped = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        context.write(wrapOutboundOut(wrapped), promise: promise)
    }
}

/// Bidirectionally forwards data between a local TCP connection and an SSH
/// forwarded channel.
private final class DataForwardingHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let peer: Channel

    init(localChannel: Channel) {
        peer = localChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        peer.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        peer.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        AppLog.error("SSH forward handler error: \(error.localizedDescription)")
        context.close(promise: nil)
    }
}
