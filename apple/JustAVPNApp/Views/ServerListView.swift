import SwiftUI
import JustAVPNCore

struct ServerListView: View {
    @EnvironmentObject var configStore: ConfigStore
    @EnvironmentObject var tunnel: TunnelManager
    @State private var showAddServer = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(configStore.servers) { server in
                    ServerRow(
                        server: server,
                        isActive: configStore.activeServerID == server.id,
                        isConnected: tunnel.state.isActive && configStore.activeServerID == server.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        configStore.setActive(server)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        configStore.removeServer(configStore.servers[index])
                    }
                }
            }
            .overlay {
                if configStore.servers.isEmpty {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text("Add a server to get started")
                    )
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                Button(action: { showAddServer = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddServer) {
                AddServerView()
            }
        }
    }
}

struct ServerRow: View {
    let server: ServerConfig
    let isActive: Bool
    let isConnected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .fontWeight(isActive ? .semibold : .regular)
                Text(server.endpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
