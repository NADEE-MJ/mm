import SwiftUI

enum AccentStyle: String, CaseIterable, Hashable {
    case sky
    case mint
    case coral
    case violet

    var colors: [Color] {
        switch self {
        case .sky:
            return [Color.blue, Color.cyan]
        case .mint:
            return [Color.green, Color.mint]
        case .coral:
            return [Color.orange, Color.red]
        case .violet:
            return [Color.indigo, Color.purple]
        }
    }
}

struct SpotlightCard: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: AccentStyle
}

struct LibraryEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    var progress: Int
    var isFavorite: Bool
}

enum DemoData {
    static let spotlight: [SpotlightCard] = [
        SpotlightCard(
            id: "live-widgets",
            title: "Live Widgets",
            subtitle: "Pin interactive cards and jump into actions instantly.",
            icon: "rectangle.3.group.bubble.left.fill",
            accent: .sky
        ),
        SpotlightCard(
            id: "smart-search",
            title: "Smart Search",
            subtitle: "Find anything with instant filtering and quick previews.",
            icon: "magnifyingglass.circle.fill",
            accent: .mint
        ),
        SpotlightCard(
            id: "focus-modes",
            title: "Focus Modes",
            subtitle: "Adaptive scenes for work, travel, and personal routines.",
            icon: "moon.stars.fill",
            accent: .violet
        ),
        SpotlightCard(
            id: "quick-capture",
            title: "Quick Capture",
            subtitle: "Capture ideas in one tap and sync them later.",
            icon: "bolt.badge.clock.fill",
            accent: .coral
        )
    ]

    static let library: [LibraryEntry] = [
        LibraryEntry(
            id: "design-system",
            title: "Design System",
            detail: "Reusable UI kit with dynamic colors and modern typography.",
            icon: "paintpalette.fill",
            progress: 84,
            isFavorite: true
        ),
        LibraryEntry(
            id: "experiments",
            title: "Interaction Experiments",
            detail: "Micro-interactions, transitions, and animated components.",
            icon: "wand.and.stars.inverse",
            progress: 61,
            isFavorite: false
        ),
        LibraryEntry(
            id: "onboarding",
            title: "Onboarding Flow",
            detail: "Short, adaptive onboarding with contextual tips.",
            icon: "figure.walk.motion",
            progress: 45,
            isFavorite: false
        ),
        LibraryEntry(
            id: "offline-pack",
            title: "Offline Pack",
            detail: "Essential features cached for low-connectivity scenarios.",
            icon: "wifi.slash",
            progress: 72,
            isFavorite: true
        )
    ]
}
