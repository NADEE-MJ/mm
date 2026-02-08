import SwiftUI

enum TabItem: String, CaseIterable, Identifiable {
    case home
    case lists
    case people
    case account
    case explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .lists: "Lists"
        case .people: "People"
        case .account: "Account"
        case .explore: "Explore"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .lists: "list.bullet"
        case .people: "person.2.fill"
        case .account: "person.circle.fill"
        case .explore: "sparkles"
        }
    }
}
