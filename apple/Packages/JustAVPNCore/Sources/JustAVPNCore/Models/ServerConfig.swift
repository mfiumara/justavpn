import Foundation

public struct ServerConfig: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var endpoint: String      // host:port
    public var publicKey: String
    public var presharedKey: String?
    public var address: String       // client IP, e.g. "10.66.66.2/32"
    public var dns: String
    public var allowedIPs: String    // typically "0.0.0.0/0, ::/0"
    public var persistentKeepalive: Int

    public init(
        id: UUID = UUID(),
        name: String,
        endpoint: String,
        publicKey: String,
        presharedKey: String? = nil,
        address: String,
        dns: String = "1.1.1.1, 1.0.0.1",
        allowedIPs: String = "0.0.0.0/0, ::/0",
        persistentKeepalive: Int = 25
    ) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.publicKey = publicKey
        self.presharedKey = presharedKey
        self.address = address
        self.dns = dns
        self.allowedIPs = allowedIPs
        self.persistentKeepalive = persistentKeepalive
    }

    /// Parse a standard WireGuard .conf file into a ServerConfig
    public static func fromWireGuardConfig(_ text: String, name: String = "Imported Server") -> ServerConfig? {
        var privateKey = ""
        var address = ""
        var dns = "1.1.1.1"
        var publicKey = ""
        var presharedKey: String?
        var endpoint = ""
        var allowedIPs = "0.0.0.0/0, ::/0"
        var keepalive = 25

        var inInterface = false
        var inPeer = false

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[Interface]") { inInterface = true; inPeer = false; continue }
            if trimmed.hasPrefix("[Peer]") { inPeer = true; inInterface = false; continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let value = parts[1]

            if inInterface {
                switch key {
                case "PrivateKey": privateKey = value
                case "Address": address = value
                case "DNS": dns = value
                default: break
                }
            } else if inPeer {
                switch key {
                case "PublicKey": publicKey = value
                case "PresharedKey": presharedKey = value
                case "Endpoint": endpoint = value
                case "AllowedIPs": allowedIPs = value
                case "PersistentKeepalive": keepalive = Int(value) ?? 25
                default: break
                }
            }
        }

        guard !publicKey.isEmpty, !endpoint.isEmpty, !address.isEmpty else {
            return nil
        }

        // The private key is stored separately in keychain, not in this model.
        // Caller is responsible for saving it via KeychainHelper.
        let config = ServerConfig(
            name: name,
            endpoint: endpoint,
            publicKey: publicKey,
            presharedKey: presharedKey,
            address: address,
            dns: dns,
            allowedIPs: allowedIPs,
            persistentKeepalive: keepalive
        )
        return config
    }
}
