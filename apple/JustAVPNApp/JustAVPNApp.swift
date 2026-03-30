import SwiftUI
import JustAVPNCore

@main
struct JustAVPNApp: App {
    @StateObject private var tunnelManager = TunnelManager.shared
    @StateObject private var configStore = ConfigStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tunnelManager)
                .environmentObject(configStore)
        }
    }
}
