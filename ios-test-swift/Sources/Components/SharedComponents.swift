import SwiftUI

// MARK: - Frosted Card (Liquid Glass)

struct FrostedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Divider

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.stroke)
            .frame(height: 1)
            .padding(.leading, 52)
    }
}

// MARK: - Circle Icon Button (Liquid Glass Interactive)

struct CircleIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive, in: .circle)
    }
}

// MARK: - Page Background (lightweight, no blur)

struct PageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.background, AppTheme.backgroundAccent],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
