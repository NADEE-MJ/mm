import SwiftUI

struct WorkoutTypeChip: View {
    let name: String
    let slug: String

    var body: some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.color(for: slug).opacity(0.2), in: Capsule())
            .overlay(
                Capsule().stroke(AppTheme.color(for: slug), lineWidth: 1)
            )
    }
}
