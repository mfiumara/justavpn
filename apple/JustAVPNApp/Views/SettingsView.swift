import SwiftUI
import JustAVPNCore

struct SettingsView: View {
    @EnvironmentObject var tunnel: TunnelManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Kill Switch", isOn: $tunnel.killSwitch)
                    Toggle("Auto-Connect", isOn: $tunnel.autoConnect)
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Kill Switch blocks all internet traffic when the VPN disconnects unexpectedly. Auto-Connect reconnects automatically when your network changes.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Protocol", value: "WireGuard")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
