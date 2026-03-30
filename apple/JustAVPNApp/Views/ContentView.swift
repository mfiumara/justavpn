import SwiftUI
import JustAVPNCore

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConnectionView()
                .tabItem {
                    Label("VPN", systemImage: "shield.checkered")
                }
                .tag(0)

            ServerListView()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}
