import SwiftUI

enum TabItem: String, CaseIterable, Hashable {
    case home
    case library

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .library:
            return "Library"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "sparkles"
        case .library:
            return "square.stack.3d.up.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .home:
            return [Color.blue, Color.cyan]
        case .library:
            return [Color.indigo, Color.mint]
        }
    }
}
