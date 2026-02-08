import Foundation

struct WorkRow: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
}

struct InboxThread: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let unreadCount: Int
}

struct RepoItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let language: String
    let languageColorHex: String
    let stars: Int
}

struct ProfileAction: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

enum DemoData {
    static let workRows: [WorkRow] = [
        WorkRow(id: "issues", title: "Issues", icon: "exclamationmark.circle.fill"),
        WorkRow(id: "pulls", title: "Pull Requests", icon: "arrow.triangle.pull"),
        WorkRow(id: "discussions", title: "Discussions", icon: "bubble.left.and.bubble.right.fill"),
        WorkRow(id: "projects", title: "Projects", icon: "square.grid.2x2.fill"),
        WorkRow(id: "orgs", title: "Organizations", icon: "building.2.fill"),
        WorkRow(id: "starred", title: "Starred", icon: "star.fill")
    ]

    static let inboxThreads: [InboxThread] = [
        InboxThread(id: "1", title: "CI Build Ready", subtitle: "Swift test IPA is available for download.", unreadCount: 1),
        InboxThread(id: "2", title: "Review Requested", subtitle: "Update the floating tab bar transitions.", unreadCount: 2),
        InboxThread(id: "3", title: "Release Updated", subtitle: "ios-swift-test-latest now points to latest commit.", unreadCount: 0)
    ]

    static let repositories: [RepoItem] = [
        RepoItem(id: "discord-bot", name: "discord-bot", description: "discord bot to do actions on my server remotely", language: "Python", languageColorHex: "#3572A5", stars: 0),
        RepoItem(id: "python-live", name: "python_live_lambda", description: "AWS Lambda automation utilities", language: "Python", languageColorHex: "#3572A5", stars: 0),
        RepoItem(id: "mm", name: "mm", description: "Movie Manager, flip it around WICKED WITCH", language: "TypeScript", languageColorHex: "#3178C6", stars: 0),
        RepoItem(id: "maida-server", name: "maida-server", description: "FastAPI backend services", language: "Python", languageColorHex: "#3572A5", stars: 0),
        RepoItem(id: "raddle", name: "raddle.teams", description: "A team based version of raddle.quest", language: "TypeScript", languageColorHex: "#3178C6", stars: 0),
        RepoItem(id: "zsh", name: "zsh", description: "My zsh setup and config files.", language: "Shell", languageColorHex: "#89E051", stars: 0)
    ]

    static let profileActions: [ProfileAction] = [
        ProfileAction(id: "repositories", title: "Repositories", value: "32", icon: "folder.fill"),
        ProfileAction(id: "starred", title: "Starred", value: "151", icon: "star.fill"),
        ProfileAction(id: "organizations", title: "Organizations", value: "2", icon: "building.2.fill"),
        ProfileAction(id: "projects", title: "Projects", value: "4", icon: "square.grid.2x2")
    ]
}
