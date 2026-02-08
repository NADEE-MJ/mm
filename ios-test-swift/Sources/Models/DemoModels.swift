import Foundation

// MARK: - Data Models

struct WorkRow: Identifiable, Hashable {
    let id: String
    var title: String
    let icon: String
    var isFavorite: Bool = false
}

struct InboxThread: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let sender: String
    let timestamp: String
    var unreadCount: Int
    var isArchived: Bool = false
}

struct RepoItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let language: String
    let languageColorHex: String
    let stars: Int
    let owner: String
    let lastUpdated: String
}

struct ProfileAction: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

struct CommunityMember: Identifiable, Hashable {
    let id: String
    var name: String
    var role: String
    var avatar: String
}

// MARK: - Sample Data

enum DemoData {
    static let workRows: [WorkRow] = [
        WorkRow(id: "issues", title: "Issues", icon: "exclamationmark.circle.fill"),
        WorkRow(id: "pulls", title: "Pull Requests", icon: "arrow.triangle.pull"),
        WorkRow(id: "discussions", title: "Discussions", icon: "bubble.left.and.bubble.right.fill"),
        WorkRow(id: "projects", title: "Projects", icon: "square.grid.2x2.fill"),
        WorkRow(id: "orgs", title: "Organizations", icon: "building.2.fill"),
        WorkRow(id: "starred", title: "Starred", icon: "star.fill"),
        WorkRow(id: "repos", title: "Repositories", icon: "folder.fill"),
        WorkRow(id: "actions", title: "Actions", icon: "bolt.fill"),
        WorkRow(id: "packages", title: "Packages", icon: "shippingbox.fill"),
        WorkRow(id: "security", title: "Security", icon: "lock.shield.fill")
    ]

    static let inboxThreads: [InboxThread] = [
        InboxThread(id: "1", title: "CI Build Ready", subtitle: "Swift test IPA is available for download.", sender: "github-actions", timestamp: "2m", unreadCount: 1),
        InboxThread(id: "2", title: "Review Requested", subtitle: "Update the floating tab bar transitions.", sender: "collaborator", timestamp: "15m", unreadCount: 2),
        InboxThread(id: "3", title: "Release Updated", subtitle: "ios-swift-test-latest now points to latest commit.", sender: "release-bot", timestamp: "1h", unreadCount: 0),
        InboxThread(id: "4", title: "Issue Assigned", subtitle: "Fix dark mode colors on the explore page.", sender: "project-lead", timestamp: "3h", unreadCount: 1),
        InboxThread(id: "5", title: "PR Merged", subtitle: "Liquid glass effects merged into main.", sender: "ci-bot", timestamp: "5h", unreadCount: 0),
        InboxThread(id: "6", title: "Mention in Discussion", subtitle: "What do you think about the new tab design?", sender: "designer", timestamp: "1d", unreadCount: 3),
        InboxThread(id: "7", title: "Dependabot Alert", subtitle: "Security vulnerability found in dependency.", sender: "dependabot", timestamp: "2d", unreadCount: 1)
    ]

    static let repositories: [RepoItem] = [
        RepoItem(id: "mm", name: "mm", description: "Movie Manager — flip it around WICKED WITCH", language: "TypeScript", languageColorHex: "#3178C6", stars: 8, owner: "NADEE-MJ", lastUpdated: "Today"),
        RepoItem(id: "discord-bot", name: "discord-bot", description: "Discord bot to do actions on my server remotely", language: "Python", languageColorHex: "#3572A5", stars: 12, owner: "NADEE-MJ", lastUpdated: "2 days ago"),
        RepoItem(id: "python-live", name: "python_live_lambda", description: "AWS Lambda automation utilities", language: "Python", languageColorHex: "#3572A5", stars: 3, owner: "NADEE-MJ", lastUpdated: "1 week ago"),
        RepoItem(id: "maida-server", name: "maida-server", description: "FastAPI backend services", language: "Python", languageColorHex: "#3572A5", stars: 1, owner: "NADEE-MJ", lastUpdated: "3 days ago"),
        RepoItem(id: "raddle", name: "raddle.teams", description: "A team based version of raddle.quest", language: "TypeScript", languageColorHex: "#3178C6", stars: 5, owner: "NADEE-MJ", lastUpdated: "5 days ago"),
        RepoItem(id: "zsh", name: "zsh", description: "My zsh setup and config files", language: "Shell", languageColorHex: "#89E051", stars: 2, owner: "NADEE-MJ", lastUpdated: "1 month ago"),
        RepoItem(id: "swift-test", name: "swift-test", description: "iOS 26 Swift test application with liquid glass", language: "Swift", languageColorHex: "#F05138", stars: 0, owner: "NADEE-MJ", lastUpdated: "Just now"),
        RepoItem(id: "ml-notebook", name: "ml-notebook", description: "Machine learning experiments and notebooks", language: "Jupyter Notebook", languageColorHex: "#DA5B0B", stars: 4, owner: "NADEE-MJ", lastUpdated: "2 weeks ago")
    ]

    static let profileActions: [ProfileAction] = [
        ProfileAction(id: "repositories", title: "Repositories", value: "32", icon: "folder.fill"),
        ProfileAction(id: "starred", title: "Starred", value: "151", icon: "star.fill"),
        ProfileAction(id: "organizations", title: "Organizations", value: "2", icon: "building.2.fill"),
        ProfileAction(id: "projects", title: "Projects", value: "4", icon: "square.grid.2x2")
    ]

    static let communityMembers: [CommunityMember] = [
        CommunityMember(id: "1", name: "Alice Chen", role: "iOS Developer", avatar: "person.circle.fill"),
        CommunityMember(id: "2", name: "Bob Martinez", role: "Backend Engineer", avatar: "person.circle.fill"),
        CommunityMember(id: "3", name: "Carol Davis", role: "Designer", avatar: "person.circle.fill"),
        CommunityMember(id: "4", name: "Dave Wilson", role: "DevOps", avatar: "person.circle.fill"),
        CommunityMember(id: "5", name: "Eve Johnson", role: "ML Engineer", avatar: "person.circle.fill"),
        CommunityMember(id: "6", name: "Frank Lee", role: "QA Engineer", avatar: "person.circle.fill"),
        CommunityMember(id: "7", name: "Grace Kim", role: "Product Manager", avatar: "person.circle.fill"),
        CommunityMember(id: "8", name: "Hank Brown", role: "Full Stack Dev", avatar: "person.circle.fill")
    ]
}
