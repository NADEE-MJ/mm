import SwiftUI

enum TabItem: String, Hashable, CaseIterable {
    case home
    case people

    var title: String {
        switch self {
        case .home: "Movies"
        case .people: "People"
        }
    }

    var icon: String {
        switch self {
        case .home: "film.fill"
        case .people: "person.2.fill"
        }
    }
}
