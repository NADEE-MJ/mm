import SwiftUI

// MARK: - Server Detail

struct ServerDetailView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var wsManager: WebSocketManager

    init(server: ServerInfo, networkService: NetworkService) {
        self.server = server
        self.networkService = networkService
        _wsManager = State(initialValue: WebSocketManager(serverId: server.id))
    }

    private var metrics: SystemMetrics {
        wsManager.metrics ?? SystemMetrics(cpu: 0, memory: 0, disk: 0, uptime: 0, loadAvg: [0, 0, 0])
    }

    var body: some View {
        List {
            // MARK: Metrics summary
            metricsSection

            // MARK: Navigation sections
            Section("Manage") {
                navRow(
                    title: "Services",
                    subtitle: "Systemd / launchd / brew units",
                    icon: "switch.2",
                    color: .blue
                ) {
                    ServicesView(server: server, networkService: networkService)
                        .navigationTitle("Services")
                        .navigationBarTitleDisplayMode(.inline)
                }

                navRow(
                    title: "Docker",
                    subtitle: "Containers on this server",
                    icon: "shippingbox",
                    color: .cyan
                ) {
                    DockerView(server: server, networkService: networkService)
                        .navigationTitle("Docker")
                        .navigationBarTitleDisplayMode(.inline)
                }

                navRow(
                    title: "Git",
                    subtitle: "Pull, checkout & branch status",
                    icon: "point.3.connected.trianglepath.dotted",
                    color: .orange
                ) {
                    GitView(server: server, networkService: networkService)
                        .navigationTitle("Git")
                        .navigationBarTitleDisplayMode(.inline)
                }

                navRow(
                    title: "Packages",
                    subtitle: "Track system package updates",
                    icon: "cube.box",
                    color: .purple
                ) {
                    PackagesView(server: server, networkService: networkService)
                        .navigationTitle("Packages")
                        .navigationBarTitleDisplayMode(.inline)
                }

                if server.type == .local {
                    navRow(
                        title: "Jobs",
                        subtitle: "Scheduled cron tasks",
                        icon: "clock",
                        color: .teal
                    ) {
                        JobsView(networkService: networkService)
                            .navigationTitle("Jobs")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }

            // MARK: Power — separate section with red tint to signal danger
            Section {
                navRow(
                    title: "Power",
                    subtitle: "Restart or shut down",
                    icon: "power.circle.fill",
                    color: .red
                ) {
                    PowerView(server: server, networkService: networkService)
                        .navigationTitle("Power")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { wsManager.start() }
        .onDisappear { wsManager.stop() }
    }

    // MARK: - Metrics section

    private var metricsSection: some View {
        Section("Resources") {
            HStack(spacing: 0) {
                MetricGaugeView(title: "CPU", value: metrics.cpu, color: .orange)
                    .frame(maxWidth: .infinity)
                MetricGaugeView(title: "Memory", value: metrics.memory, color: .blue)
                    .frame(maxWidth: .infinity)
                MetricGaugeView(title: "Disk", value: metrics.disk, color: .red)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)

            LabeledContent("Uptime", value: formatUptime(metrics.uptime))

            LabeledContent("Load") {
                Text(metrics.loadAvg.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
            }

            if let error = wsManager.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Navigation row builder

    @ViewBuilder
    private func navRow<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 28)
            }
        }
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
