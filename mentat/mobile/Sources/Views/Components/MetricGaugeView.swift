import SwiftUI

struct MetricGaugeView: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        Gauge(value: value, in: 0...100) {
            Text(title)
        } currentValueLabel: {
            Text("\(value, specifier: "%.1f")%")
        }
        .tint(color)
        .gaugeStyle(.accessoryCircular)
        .padding(.vertical, 4)
    }
}
