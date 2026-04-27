import SwiftUI

struct StatusBadgeView: View {
    let status: String

    var color: Color {
        switch status.lowercased() {
        case "running", "connected", "active", "enabled":
            return .green
        case "stopped", "unreachable":
            return .orange
        case "error", "failed", "disabled":
            return .red
        default:
            return Color(UIColor.secondaryLabel)
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
