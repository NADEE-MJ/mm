import SwiftUI

enum TabItem: String, Hashable, CaseIterable {
    case home
    case explore
    case people

    var title: String {
        switch self {
        case .home: "Movies"
        case .explore: "Explore"
        case .people: "People"
        }
    }

    var icon: String {
        switch self {
        case .home: "film.fill"
        case .explore: "sparkle.magnifyingglass"
        case .people: "person.2.fill"
        }
    }
}
