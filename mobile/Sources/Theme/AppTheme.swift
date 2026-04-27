import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let backgroundAccent = Color(red: 0.08, green: 0.11, blue: 0.18)

    static let surface = Color(red: 0.10, green: 0.12, blue: 0.18)
    static let surfaceMuted = Color(red: 0.12, green: 0.14, blue: 0.20)

    static let stroke = Color.white.opacity(0.08)
    static let strongStroke = Color.white.opacity(0.18)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.55)

    static let blue = Color(red: 0.12, green: 0.63, blue: 1.00)
}

enum PersonAppearance {
    static let colorHexOptions = [
        "#0a84ff", // Blue
        "#30d158", // Green
        "#ff9f0a", // Orange
        "#bf5af2", // Purple
        "#ff375f", // Pink
        "#64d2ff", // Teal
        "#ffd60a", // Yellow
        "#8e8e93", // Gray
    ]

    static let emojiOptions = [
        "🍿", "🎬", "🎯", "🔥", "🌟", "💡", "🤝", "🎲", "🧠", "📽️",
    ]

    static let defaultColorHex = "#0a84ff"
    static let quickFallbackColorHex = "#bf5af2"
    static let regularFallbackColorHex = "#8e8e93"
    static let minimumControlSize: CGFloat = 44

    static func normalizedEmoji(_ emoji: String?) -> String? {
        guard let emoji else { return nil }
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func avatarText(name: String, emoji: String?) -> String {
        if let emoji = normalizedEmoji(emoji) {
            return emoji
        }
        return String(name.prefix(1)).uppercased()
    }

    static func color(from hex: String?, isQuick: Bool) -> Color {
        if let hex, let color = Color(hex: hex) {
            return color
        }
        let fallback = isQuick ? quickFallbackColorHex : regularFallbackColorHex
        return Color(hex: fallback) ?? Color.accentColor
    }

    static func colorName(for hex: String) -> String {
        switch hex.lowercased() {
        case "#0a84ff": "Blue"
        case "#30d158": "Green"
        case "#ff9f0a": "Orange"
        case "#bf5af2": "Purple"
        case "#ff375f": "Pink"
        case "#64d2ff": "Teal"
        case "#ffd60a": "Yellow"
        case "#8e8e93": "Gray"
        default: "Custom Color"
        }
    }

    static func avatarForegroundColor(for hex: String?, isQuick: Bool) -> Color {
        let trimmedHex = hex?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedHex = (trimmedHex?.isEmpty == false ? trimmedHex : nil)
            ?? (isQuick ? quickFallbackColorHex : regularFallbackColorHex)

        guard let components = colorComponents(from: resolvedHex) else {
            return .white
        }

        // Relative luminance helps maintain contrast for bright avatar colors.
        let luminance = (0.2126 * components.red) + (0.7152 * components.green) + (0.0722 * components.blue)
        return luminance > 0.64 ? .black : .white
    }

    private static func colorComponents(from hex: String) -> (red: Double, green: Double, blue: Double)? {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, var value = UInt64(cleaned, radix: 16) else { return nil }

        let red = Double((value & 0xFF00_00) >> 16) / 255
        value = value & 0x00FF_FF
        let green = Double((value & 0x00FF_00) >> 8) / 255
        let blue = Double(value & 0x0000_FF) / 255
        return (red, green, blue)
    }
}

struct PersonAvatarView: View {
    let name: String
    let emoji: String?
    let colorHex: String?
    let isQuick: Bool
    let isTrusted: Bool
    var size: CGFloat = 40

    var body: some View {
        let foreground = PersonAppearance.avatarForegroundColor(for: colorHex, isQuick: isQuick)

        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(PersonAppearance.color(from: colorHex, isQuick: isQuick))

            Text(PersonAppearance.avatarText(name: name, emoji: emoji))
                .font(size >= 44 ? .title3 : .headline)
                .fontWeight(.bold)
                .foregroundStyle(foreground)

            if isTrusted {
                Image(systemName: "star.fill")
                    .font(.system(size: max(11, size * 0.28), weight: .bold))
                    .foregroundStyle(.yellow)
                    .padding(3)
                    .background(Circle().fill(.ultraThinMaterial))
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "\(name), \(isQuick ? "quick " : "")\(isTrusted ? "trusted " : "")recommender avatar"
            )
        )
    }
}

private extension Color {
    init?(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if cleaned.count == 8 {
            alpha = Double((value & 0xFF00_0000) >> 24) / 255
            red = Double((value & 0x00FF_0000) >> 16) / 255
            green = Double((value & 0x0000_FF00) >> 8) / 255
            blue = Double(value & 0x0000_00FF) / 255
        } else {
            alpha = 1
            red = Double((value & 0xFF00_00) >> 16) / 255
            green = Double((value & 0x00FF_00) >> 8) / 255
            blue = Double(value & 0x0000_FF) / 255
        }

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
