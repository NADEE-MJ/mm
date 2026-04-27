import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.04, green: 0.06, blue: 0.10)
    static let backgroundAccent = Color(red: 0.09, green: 0.12, blue: 0.19)
    static let surface = Color(red: 0.11, green: 0.14, blue: 0.22)
    static let surfaceMuted = Color(red: 0.15, green: 0.18, blue: 0.26)
    static let stroke = Color.white.opacity(0.10)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)

    static let gymboBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let gymboGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let gymboRed = Color(red: 1.0, green: 0.23, blue: 0.37)
    static let gymboOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let gymboTeal = Color(red: 0.19, green: 0.82, blue: 0.78)

    static func color(for slug: String) -> Color {
        switch slug {
        case "lifting": return AppTheme.gymboBlue
        case "running": return AppTheme.gymboGreen
        case "pilates": return AppTheme.gymboTeal
        case "mobility": return Color(red: 1.0, green: 0.84, blue: 0.04)
        case "plyometric": return AppTheme.gymboOrange
        case "hyrox": return AppTheme.gymboRed
        default: return Color(red: 0.39, green: 0.82, blue: 1.0)
        }
    }

    static let heroGradient = LinearGradient(
        colors: [backgroundAccent, background],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
