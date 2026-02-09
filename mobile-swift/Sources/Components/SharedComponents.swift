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

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.interactive() : .regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: isSelected)
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

// MARK: - Movie Poster Image

struct MoviePosterImage: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure, .empty:
                Rectangle()
                    .fill(AppTheme.surfaceMuted)
                    .overlay {
                        Image(systemName: "film")
                            .font(.system(size: min(width, height) * 0.3))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
            @unknown default:
                Rectangle().fill(AppTheme.surfaceMuted)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Star Rating Display

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int

    init(_ rating: Double, max maxRating: Int = 10) {
        self.rating = rating
        self.maxRating = maxRating
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", rating))
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.yellow)
    }
}

// MARK: - Account Toolbar Button

struct AccountToolbarButton: View {
    let action: () -> Void
    @State private var authManager = AuthManager.shared

    private var initials: String {
        guard let user = authManager.user else {
            return "MM"
        }
        let username = user.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return "MM" }
        return String(username.prefix(2)).uppercased()
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.surfaceMuted, AppTheme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(initials)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    )

                Circle()
                    .fill(AppTheme.blue)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.background, lineWidth: 1.5)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open account")
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
