import SwiftUI

enum TabItem: String, CaseIterable, Identifiable {
    case log
    case builder
    case progress
    case account

    var id: String { rawValue }

    var title: String {
        switch self {
        case .log: "Log"
        case .builder: "Build"
        case .progress: "Progress"
        case .account: "Account"
        }
    }

    var icon: String {
        switch self {
        case .log: "dumbbell"
        case .builder: "square.stack.3d.up"
        case .progress: "chart.line.uptrend.xyaxis"
        case .account: "person"
        }
    }
}
