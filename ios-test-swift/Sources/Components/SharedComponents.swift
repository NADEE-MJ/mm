import SwiftUI

// MARK: - Frosted Card (Liquid Glass)

struct FrostedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
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
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.blue)
            }
        }
    }
}

// MARK: - Badge

struct BadgeView: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.blue, in: .capsule)
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
                .symbolEffect(.pulse)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Detail View (reusable stub)

struct DetailView: View {
    let title: String
    let icon: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.blue)
                    .symbolEffect(.bounce, options: .nonRepeating)

                Text(title)
                    .font(.largeTitle.bold())

                Text("This is a demo detail page for **\(title)**. In a real app this would show rich content.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                FrostedCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Created: Today", systemImage: "calendar")
                        DividerLine()
                        Label("Status: Active", systemImage: "checkmark.circle.fill")
                        DividerLine()
                        Label("Priority: High", systemImage: "exclamationmark.triangle.fill")
                    }
                    .padding(16)
                }

                Spacer()
            }
            .padding(24)
        }
        .background { PageBackground() }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}

// MARK: - Page Background

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

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
