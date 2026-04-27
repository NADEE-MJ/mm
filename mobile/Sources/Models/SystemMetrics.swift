import Foundation

struct SystemMetrics: Codable, Hashable {
    let cpu: Double
    let memory: Double
    let disk: Double
    let uptime: Int
    let loadAvg: [Double]
}
