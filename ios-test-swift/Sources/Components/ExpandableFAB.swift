import SwiftUI

// MARK: - FAB Action Model

struct FABAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

// MARK: - Expandable Floating Action Button

struct ExpandableFAB: View {
    @Binding var isExpanded: Bool
    let actions: [FABAction]

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Expanded action rows
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
                if isExpanded {
                    fabRow(item: item, index: index)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity),
                                removal: .scale(scale: 0.6).combined(with: .opacity)
                            )
                        )
                }
            }

            // Main button
            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        isExpanded ? Color.gray : AppTheme.blue,
                        in: .circle
                    )
                    .shadow(
                        color: (isExpanded ? Color.gray : AppTheme.blue).opacity(0.35),
                        radius: 10, y: 4
                    )
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .solid), trigger: isExpanded)
        }
    }

    // MARK: - Row

    private func fabRow(item: FABAction, index: Int) -> some View {
        HStack(spacing: 10) {
            Text(item.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)

            Button {
                item.action()
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded = false
                }
            } label: {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(item.color, in: .circle)
                    .shadow(color: item.color.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
}
