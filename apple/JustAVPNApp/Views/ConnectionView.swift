import SwiftUI
import JustAVPNCore

struct ConnectionView: View {
    @EnvironmentObject var tunnel: TunnelManager
    @EnvironmentObject var configStore: ConfigStore
    @State private var showPausePicker = false
    @State private var connectedSince: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Status indicator
                StatusBadge(state: tunnel.state)

                // Server info
                if let server = configStore.activeServer {
                    VStack(spacing: 4) {
                        Text(server.name)
                            .font(.headline)
                        Text(server.endpoint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No server configured")
                        .foregroundStyle(.secondary)
                }

                // Connection duration
                if case .connected(let since) = tunnel.state {
                    Text(since, style: .timer)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Connect button
                Button(action: { tunnel.toggle() }) {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: buttonColor.opacity(0.4), radius: 16)
                }
                .disabled(configStore.activeServer == nil)

                Text(tunnel.state.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Pause button (only when connected)
                if case .connected = tunnel.state {
                    Button("Pause VPN") {
                        showPausePicker = true
                    }
                    .buttonStyle(.bordered)
                }

                if case .paused = tunnel.state {
                    Button("Resume Now") {
                        tunnel.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("JustAVPN")
            .sheet(isPresented: $showPausePicker) {
                PauseTimerPicker { duration in
                    tunnel.pause(duration: duration)
                    showPausePicker = false
                }
                .presentationDetents([.height(250)])
            }
        }
    }

    private var buttonColor: Color {
        switch tunnel.state {
        case .connected: return .green
        case .connecting, .disconnecting: return .yellow
        case .paused: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    private var buttonIcon: String {
        switch tunnel.state {
        case .connected: return "lock.shield.fill"
        case .connecting, .disconnecting: return "ellipsis"
        case .paused: return "pause.fill"
        default: return "shield.slash"
        }
    }
}
