import SwiftUI

struct ServerDetailView: View {
    let server: ServerInfo
    let networkService: NetworkService
    @Bindable var authManager: AuthManager

    var body: some View {
        TabView {
            DashboardView(server: server, networkService: networkService)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            ServicesView(server: server, networkService: networkService)
                .tabItem {
                    Label("Services", systemImage: "switch.2")
                }

            DockerView(server: server, networkService: networkService)
                .tabItem {
                    Label("Docker", systemImage: "shippingbox")
                }

            GitView(server: server, networkService: networkService)
                .tabItem {
                    Label("Git", systemImage: "point.3.connected.trianglepath.dotted")
                }

            PackagesView(server: server, networkService: networkService)
                .tabItem {
                    Label("Packages", systemImage: "cube.box")
                }

            SSHView(server: server, networkService: networkService)
                .tabItem {
                    Label("SSH", systemImage: "terminal")
                }

            if server.type == .local {
                JobsView(networkService: networkService)
                    .tabItem {
                        Label("Jobs", systemImage: "clock")
                    }
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
