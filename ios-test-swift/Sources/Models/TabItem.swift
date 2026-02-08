import SwiftUI

enum TabItem: String, CaseIterable, Hashable {
    case home
    case inbox
    case explore
    case profile
    case community

    var title: String {
        switch self {
        case .home: "Home"
        case .inbox: "Inbox"
        case .explore: "Explore"
        case .profile: "Profile"
        case .community: "Community"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .inbox: "tray.full.fill"
        case .explore: "safari.fill"
        case .profile: "person.crop.circle.fill"
        case .community: "person.2.fill"
        }
    }
}
