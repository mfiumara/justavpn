import Foundation

public final class ServerAPIClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
        self.session = URLSession.shared
    }

    public struct ServerStatus: Codable {
        public let publicKey: String
        public let listenPort: String
        public let endpoint: String
        public let peerCount: Int
    }

    public struct PeerInfo: Codable {
        public let name: String
        public let publicKey: String
        public let ip: String
        public let created: String
        public let lastHandshake: String?
        public let transferRx: Int64?
        public let transferTx: Int64?
    }

    public struct CreatePeerResponse: Codable {
        public let peer: PeerInfo
        public let clientConfig: String
    }

    public func getStatus() async throws -> ServerStatus {
        try await request("GET", path: "/api/v1/status")
    }

    public func listPeers() async throws -> [PeerInfo] {
        try await request("GET", path: "/api/v1/peers")
    }

    public func createPeer(name: String, dns: String? = nil) async throws -> CreatePeerResponse {
        var body: [String: String] = ["name": name]
        if let dns { body["dns"] = dns }
        return try await request("POST", path: "/api/v1/peers", body: body)
    }

    public func deletePeer(publicKey: String) async throws {
        let encoded = publicKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? publicKey
        let _: EmptyResponse = try await request("DELETE", path: "/api/v1/peers/\(encoded)")
    }

    private struct EmptyResponse: Codable {}

    private func request<T: Codable>(_ method: String, path: String, body: [String: String]? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 204 {
            // For DELETE with no content
            return EmptyResponse() as! T
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(http.statusCode, msg)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        }
    }
}
