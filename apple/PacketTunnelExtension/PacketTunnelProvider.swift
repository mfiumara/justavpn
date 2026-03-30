import NetworkExtension
import WireGuardKit

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter = WireGuardAdapter(with: self) { _, message in
        NSLog("WireGuard: \(message)")
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let config = buildTunnelConfiguration() else {
            completionHandler(PacketTunnelError.invalidConfiguration)
            return
        }

        adapter.start(tunnelConfiguration: config) { adapterError in
            if let adapterError {
                NSLog("WireGuard adapter start error: \(adapterError)")
                completionHandler(adapterError)
                return
            }
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop { _ in
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app (e.g., stats requests)
        adapter.getRuntimeConfiguration { configString in
            completionHandler?(configString?.data(using: .utf8))
        }
    }

    private func buildTunnelConfiguration() -> TunnelConfiguration? {
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = proto.providerConfiguration else {
            return nil
        }

        guard let privateKey = providerConfig["privateKey"] as? String,
              let publicKey = providerConfig["publicKey"] as? String,
              let endpoint = providerConfig["endpoint"] as? String,
              let address = providerConfig["address"] as? String,
              let dns = providerConfig["dns"] as? String else {
            return nil
        }

        let presharedKey = providerConfig["presharedKey"] as? String
        let allowedIPs = (providerConfig["allowedIPs"] as? String) ?? "0.0.0.0/0, ::/0"
        let keepalive = UInt16(providerConfig["persistentKeepalive"] as? String ?? "25") ?? 25

        // Build WireGuard config string and parse it
        var wgConfig = """
        [Interface]
        PrivateKey = \(privateKey)
        Address = \(address)
        DNS = \(dns)

        [Peer]
        PublicKey = \(publicKey)
        Endpoint = \(endpoint)
        AllowedIPs = \(allowedIPs)
        PersistentKeepalive = \(keepalive)
        """

        if let psk = presharedKey, !psk.isEmpty {
            wgConfig += "\nPresharedKey = \(psk)"
        }

        return try? TunnelConfiguration(fromWgQuickConfig: wgConfig, called: "JustAVPN")
    }
}

enum PacketTunnelError: Error {
    case invalidConfiguration
}
