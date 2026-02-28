import SwiftUI

struct MetricGaugeView: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Gauge(value: value, in: 0...100) {
                Text(title)
            } currentValueLabel: {
                Text("\(value, specifier: "%.1f")%")
            }
            .tint(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
