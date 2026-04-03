import Foundation
import NetworkExtension
import Combine

public final class TunnelManager: ObservableObject {
    public static let shared = TunnelManager()

    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public var killSwitch: Bool = false {
        didSet { updateOnDemandRules() }
    }
    @Published public var autoConnect: Bool = false {
        didSet { updateOnDemandRules() }
    }

    private var manager: NETunnelProviderManager?
    private var statusObserver: AnyCancellable?
    private var pauseTask: Task<Void, Never>?

    private let configStore = ConfigStore.shared

    private init() {
        loadManager()
    }

    // MARK: - Connection

    public func connect() {
        cancelPause()

        guard let server = configStore.activeServer else {
            state = .error("No server configured")
            return
        }
        guard let privateKey = configStore.privateKey(for: server) else {
            state = .error("Private key not found")
            return
        }

        state = .connecting

        loadOrCreateManager(for: server, privateKey: privateKey) { [weak self] result in
            switch result {
            case .success(let mgr):
                self?.manager = mgr
                self?.observeStatus()
                do {
                    try mgr.connection.startVPNTunnel()
                } catch {
                    self?.state = .error(error.localizedDescription)
                }
            case .failure(let error):
                self?.state = .error(error.localizedDescription)
            }
        }
    }

    public func disconnect() {
        cancelPause()
        manager?.connection.stopVPNTunnel()
    }

    public func toggle() {
        switch state {
        case .connected, .connecting:
            disconnect()
        case .disconnected, .error, .paused:
            connect()
        case .disconnecting:
            break
        }
    }

    // MARK: - Pause

    public func pause(duration: PauseDuration) {
        guard case .connected = state else { return }

        let resumeAt = Date().addingTimeInterval(TimeInterval(duration.rawValue))
        disconnect()
        state = .paused(resumeAt: resumeAt)

        pauseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration.rawValue) * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { [weak self] in
                self?.connect()
            }
        }
    }

    private func cancelPause() {
        pauseTask?.cancel()
        pauseTask = nil
    }

    // MARK: - Manager Setup

    private func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            DispatchQueue.main.async {
                self?.manager = managers?.first
                self?.observeStatus()
            }
        }
    }

    private func loadOrCreateManager(
        for server: ServerConfig,
        privateKey: String,
        completion: @escaping (Result<NETunnelProviderManager, Error>) -> Void
    ) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let mgr = managers?.first ?? NETunnelProviderManager()
            mgr.localizedDescription = "JustAVPN"

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.justavpn.app.tunnel"
            proto.serverAddress = server.endpoint

            // Pass config to the tunnel extension via providerConfiguration
            proto.providerConfiguration = [
                "endpoint": server.endpoint,
                "publicKey": server.publicKey,
                "presharedKey": server.presharedKey ?? "",
                "privateKey": privateKey,
                "address": server.address,
                "dns": server.dns,
                "allowedIPs": server.allowedIPs,
                "persistentKeepalive": "\(server.persistentKeepalive)",
            ]

            mgr.protocolConfiguration = proto
            mgr.isEnabled = true

            // Apply on-demand rules
            if let self {
                let builder = OnDemandRulesBuilder(killSwitch: self.killSwitch, autoConnect: self.autoConnect)
                let (rules, enabled) = builder.build()
                mgr.onDemandRules = rules
                mgr.isOnDemandEnabled = enabled
            }

            mgr.saveToPreferences { error in
                if let error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                mgr.loadFromPreferences { error in
                    DispatchQueue.main.async {
                        if let error {
                            completion(.failure(error))
                        } else {
                            completion(.success(mgr))
                        }
                    }
                }
            }
        }
    }

    private func updateOnDemandRules() {
        guard let manager else { return }
        let builder = OnDemandRulesBuilder(killSwitch: killSwitch, autoConnect: autoConnect)
        let (rules, enabled) = builder.build()
        manager.onDemandRules = rules
        manager.isOnDemandEnabled = enabled
        manager.saveToPreferences { _ in }
    }

    // MARK: - Status Observation

    private func observeStatus() {
        statusObserver?.cancel()

        guard let manager else { return }

        // Map initial status
        mapStatus(manager.connection.status)

        statusObserver = NotificationCenter.default
            .publisher(for: .NEVPNStatusDidChange, object: manager.connection)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.mapStatus(manager.connection.status)
            }
    }

    private func mapStatus(_ status: NEVPNStatus) {
        // Don't override pause state
        if case .paused = state { return }

        switch status {
        case .disconnected: state = .disconnected
        case .connecting: state = .connecting
        case .connected: state = .connected(since: Date())
        case .disconnecting: state = .disconnecting
        case .reasserting: state = .connecting
        case .invalid: state = .disconnected
        @unknown default: state = .disconnected
        }
    }
}
