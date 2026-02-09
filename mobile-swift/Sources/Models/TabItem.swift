import SwiftUI

enum TabItem: String, Hashable {
    case home
    case explore
    case people
    case search

    static let mainTabs: [TabItem] = [.home, .explore, .people]

    var title: String {
        switch self {
        case .home: "Home"
        case .explore: "Discover"
        case .people: "People"
        case .search: "Search"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .explore: "sparkle.magnifyingglass"
        case .people: "person.2.fill"
        case .search: "magnifyingglass"
        }
    }
}
