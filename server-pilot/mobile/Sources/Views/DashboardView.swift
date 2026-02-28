import SwiftUI

struct DashboardView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var metrics = SystemMetrics(cpu: 0, memory: 0, disk: 0, uptime: 0, loadAvg: [0, 0, 0])
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    MetricGaugeView(title: "CPU", value: metrics.cpu, color: .orange)
                    MetricGaugeView(title: "Memory", value: metrics.memory, color: .blue)
                }

                MetricGaugeView(title: "Disk", value: metrics.disk, color: .red)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Uptime: \(metrics.uptime) s")
                    Text("Load avg: \(metrics.loadAvg.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        do {
            metrics = try await networkService.fetchMetrics(serverId: server.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
