import SwiftUI

struct WeightInputView: View {
    let weightType: String
    @Binding var value: String
    let unitPreference: String
    let barbellWeight: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: $value)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Text(helperText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var label: String {
        switch weightType {
        case "bodyweight": "Bodyweight"
        case "time_based": "Seconds"
        case "distance": unitPreference == "lbs" ? "Miles" : "KM"
        case "plates": "Per Side"
        default: "Weight"
        }
    }

    private var helperText: String {
        switch weightType {
        case "dumbbell":
            if let val = Double(value) {
                return "2× \(String(format: "%.1f", val)) \(unitPreference)"
            }
            return "Per dumbbell"
        case "plates":
            if let perSide = Double(value) {
                let total = (perSide * 2) + barbellWeight
                let perSideText = String(format: "%.1f", perSide)
                let barbellText = String(format: "%.1f", barbellWeight)
                let totalText = String(format: "%.1f", total)
                return "\(perSideText)/side + \(barbellText) bar = \(totalText)"
            }
            return "Enter plate weight per side"
        case "machine":
            return "\(unitPreference) total"
        case "bodyweight":
            return "Bodyweight"
        case "time_based":
            return "Duration in seconds"
        case "distance":
            return unitPreference == "lbs" ? "Distance in miles" : "Distance in km"
        default:
            return ""
        }
    }
}
