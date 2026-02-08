import SwiftUI

struct FrostedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(AppTheme.surface.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.stroke)
            .frame(height: 1)
            .padding(.leading, 52)
    }
}

struct CircleIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 38, height: 38)
                .background(AppTheme.surfaceMuted.opacity(0.95), in: Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.background, AppTheme.backgroundAccent],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(AppTheme.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 24)
                .offset(x: 120, y: -350)
        }
        .ignoresSafeArea()
    }
}
