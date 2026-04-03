import XCTest
@testable import JustAVPNCore

final class ServerConfigTests: XCTestCase {

    // MARK: - fromWireGuardConfig

    func testParseValidConfig() {
        let conf = """
        [Interface]
        PrivateKey = cHJpdmF0ZWtleQ==
        Address = 10.66.66.2/32
        DNS = 1.1.1.1, 1.0.0.1

        [Peer]
        PublicKey = cHVibGlja2V5
        PresharedKey = cHNr
        Endpoint = 1.2.3.4:51820
        AllowedIPs = 0.0.0.0/0, ::/0
        PersistentKeepalive = 25
        """

        let config = ServerConfig.fromWireGuardConfig(conf, name: "Test")
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.name, "Test")
        XCTAssertEqual(config?.address, "10.66.66.2/32")
        XCTAssertEqual(config?.dns, "1.1.1.1, 1.0.0.1")
        XCTAssertEqual(config?.publicKey, "cHVibGlja2V5")
        XCTAssertEqual(config?.presharedKey, "cHNr")
        XCTAssertEqual(config?.endpoint, "1.2.3.4:51820")
        XCTAssertEqual(config?.allowedIPs, "0.0.0.0/0, ::/0")
        XCTAssertEqual(config?.persistentKeepalive, 25)
    }

    func testParseMinimalConfig() {
        let conf = """
        [Interface]
        PrivateKey = key
        Address = 10.0.0.2/32

        [Peer]
        PublicKey = srvkey
        Endpoint = vpn.example.com:51820
        """

        let config = ServerConfig.fromWireGuardConfig(conf)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.endpoint, "vpn.example.com:51820")
        XCTAssertEqual(config?.publicKey, "srvkey")
        XCTAssertEqual(config?.address, "10.0.0.2/32")
        XCTAssertNil(config?.presharedKey)
        // Defaults
        XCTAssertEqual(config?.name, "Imported Server")
        XCTAssertEqual(config?.persistentKeepalive, 25)
    }

    func testParseMissingPublicKey() {
        let conf = """
        [Interface]
        PrivateKey = key
        Address = 10.0.0.2/32

        [Peer]
        Endpoint = 1.2.3.4:51820
        """

        XCTAssertNil(ServerConfig.fromWireGuardConfig(conf))
    }

    func testParseMissingEndpoint() {
        let conf = """
        [Interface]
        PrivateKey = key
        Address = 10.0.0.2/32

        [Peer]
        PublicKey = srvkey
        """

        XCTAssertNil(ServerConfig.fromWireGuardConfig(conf))
    }

    func testParseMissingAddress() {
        let conf = """
        [Interface]
        PrivateKey = key

        [Peer]
        PublicKey = srvkey
        Endpoint = 1.2.3.4:51820
        """

        XCTAssertNil(ServerConfig.fromWireGuardConfig(conf))
    }

    func testParseEmptyString() {
        XCTAssertNil(ServerConfig.fromWireGuardConfig(""))
    }

    func testParseCustomKeepalive() {
        let conf = """
        [Interface]
        PrivateKey = key
        Address = 10.0.0.2/32

        [Peer]
        PublicKey = srvkey
        Endpoint = 1.2.3.4:51820
        PersistentKeepalive = 60
        """

        let config = ServerConfig.fromWireGuardConfig(conf)
        XCTAssertEqual(config?.persistentKeepalive, 60)
    }

    func testParseCustomDNS() {
        let conf = """
        [Interface]
        PrivateKey = key
        Address = 10.0.0.2/32
        DNS = 8.8.8.8

        [Peer]
        PublicKey = srvkey
        Endpoint = 1.2.3.4:51820
        """

        let config = ServerConfig.fromWireGuardConfig(conf)
        XCTAssertEqual(config?.dns, "8.8.8.8")
    }

    func testParseIPv6Endpoint() {
        let conf = """
        [Interface]
        PrivateKey = key
        Address = 10.0.0.2/32

        [Peer]
        PublicKey = srvkey
        Endpoint = [2a01:4f8::1]:51820
        """

        let config = ServerConfig.fromWireGuardConfig(conf)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.endpoint, "[2a01:4f8::1]:51820")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let config = ServerConfig(
            name: "Test",
            endpoint: "1.2.3.4:51820",
            publicKey: "key==",
            presharedKey: "psk==",
            address: "10.0.0.2/32"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)

        XCTAssertEqual(decoded.name, config.name)
        XCTAssertEqual(decoded.endpoint, config.endpoint)
        XCTAssertEqual(decoded.publicKey, config.publicKey)
        XCTAssertEqual(decoded.presharedKey, config.presharedKey)
        XCTAssertEqual(decoded.address, config.address)
        XCTAssertEqual(decoded.dns, config.dns)
        XCTAssertEqual(decoded.allowedIPs, config.allowedIPs)
        XCTAssertEqual(decoded.persistentKeepalive, config.persistentKeepalive)
    }

    // MARK: - Defaults

    func testDefaultValues() {
        let config = ServerConfig(
            name: "Test",
            endpoint: "1.2.3.4:51820",
            publicKey: "key==",
            address: "10.0.0.2/32"
        )

        XCTAssertEqual(config.dns, "1.1.1.1, 1.0.0.1")
        XCTAssertEqual(config.allowedIPs, "0.0.0.0/0, ::/0")
        XCTAssertEqual(config.persistentKeepalive, 25)
        XCTAssertNil(config.presharedKey)
    }
}
