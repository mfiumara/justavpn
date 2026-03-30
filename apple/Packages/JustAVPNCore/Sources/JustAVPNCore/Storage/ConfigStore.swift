import Foundation

public final class ConfigStore: ObservableObject {
    public static let shared = ConfigStore()

    private static let appGroupID = "group.com.justavpn.shared"
    private let defaults: UserDefaults
    private let serversKey = "savedServers"
    private let activeServerKey = "activeServerID"

    @Published public private(set) var servers: [ServerConfig] = []
    @Published public var activeServerID: UUID?

    private init() {
        defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        loadServers()
    }

    public var activeServer: ServerConfig? {
        guard let id = activeServerID else { return servers.first }
        return servers.first { $0.id == id }
    }

    public func addServer(_ config: ServerConfig, privateKey: String) {
        servers.append(config)
        KeychainHelper.shared.save(key: "pk_\(config.id.uuidString)", string: privateKey)
        saveServers()
        if servers.count == 1 {
            activeServerID = config.id
        }
    }

    public func removeServer(_ config: ServerConfig) {
        servers.removeAll { $0.id == config.id }
        KeychainHelper.shared.delete(key: "pk_\(config.id.uuidString)")
        if activeServerID == config.id {
            activeServerID = servers.first?.id
        }
        saveServers()
    }

    public func setActive(_ config: ServerConfig) {
        activeServerID = config.id
        defaults.set(config.id.uuidString, forKey: activeServerKey)
    }

    public func privateKey(for config: ServerConfig) -> String? {
        KeychainHelper.shared.loadString(key: "pk_\(config.id.uuidString)")
    }

    private func loadServers() {
        guard let data = defaults.data(forKey: serversKey),
              let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) else {
            return
        }
        servers = decoded
        if let idStr = defaults.string(forKey: activeServerKey) {
            activeServerID = UUID(uuidString: idStr)
        }
    }

    private func saveServers() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: serversKey)
        if let id = activeServerID {
            defaults.set(id.uuidString, forKey: activeServerKey)
        }
    }
}
