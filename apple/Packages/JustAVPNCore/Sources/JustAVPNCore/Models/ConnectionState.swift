import Foundation

public enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting
    case paused(resumeAt: Date)
    case error(String)

    public var isActive: Bool {
        switch self {
        case .connected, .connecting: return true
        default: return false
        }
    }

    public var statusText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting..."
        case .paused(let date):
            let remaining = max(0, date.timeIntervalSinceNow)
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "Paused (\(minutes):\(String(format: "%02d", seconds)))"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
