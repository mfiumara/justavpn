import SwiftUI
import JustAVPNCore

struct StatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(dotColor.opacity(0.15), in: Capsule())
    }

    private var dotColor: Color {
        switch state {
        case .connected: return .green
        case .connecting, .disconnecting: return .yellow
        case .paused: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    private var label: String {
        switch state {
        case .connected: return "Protected"
        case .connecting: return "Connecting"
        case .disconnecting: return "Disconnecting"
        case .paused: return "Paused"
        case .error: return "Error"
        case .disconnected: return "Unprotected"
        }
    }
}
