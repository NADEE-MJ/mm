import SwiftUI

// MARK: - Root Tab Host
// Uses native iOS 26 TabView for automatic liquid glass tab bar.
// Only the active tab is rendered, eliminating the ZStack performance cost.

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(TabItem.home.title, systemImage: TabItem.home.icon, value: .home) {
                HomePageView()
            }

            Tab(TabItem.inbox.title, systemImage: TabItem.inbox.icon, value: .inbox) {
                InboxPageView()
            }

            Tab(TabItem.explore.title, systemImage: TabItem.explore.icon, value: .explore) {
                ExplorePageView()
            }

            Tab(TabItem.profile.title, systemImage: TabItem.profile.icon, value: .profile) {
                ProfilePageView()
            }

            Tab(TabItem.community.title, systemImage: TabItem.community.icon, value: .community) {
                CommunityPageView()
            }
        }
        .tint(AppTheme.blue)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

#Preview {
    RootTabHostView()
}
