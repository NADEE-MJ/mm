import SwiftUI

enum TabItem: String, CaseIterable, Hashable {
    case home
    case explore
    case people
    case account

    var title: String {
        switch self {
        case .home: "Movies"
        case .explore: "Explore"
        case .people: "People"
        case .account: "Account"
        }
    }

    var icon: String {
        switch self {
        case .home: "film.fill"
        case .explore: "sparkle.magnifyingglass"
        case .people: "person.2.fill"
        case .account: "person.crop.circle.fill"
        }
    }
}
