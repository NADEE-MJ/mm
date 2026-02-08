import SwiftUI

enum TabItem: String, CaseIterable, Hashable {
    case home
    case inbox
    case explore
    case profile

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .inbox:
            return "Inbox"
        case .explore:
            return "Explore"
        case .profile:
            return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .inbox:
            return "tray.full.fill"
        case .explore:
            return "safari.fill"
        case .profile:
            return "person.crop.circle.fill"
        }
    }
}
