import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false
    @State private var scrollState = ScrollState()
    @State private var sheetScrollState = ScrollState()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomePageView(
                onAccountTap: { showAccount = true },
                onAddMovie: { showAddMovie = true },
                onAddPerson: { showAddPerson = true }
            )
            .tag(TabItem.home)
            .tabItem {
                Label(TabItem.home.title, systemImage: TabItem.home.icon)
            }

            ExplorePageView(
                onAccountTap: { showAccount = true },
                onAddPerson: { showAddPerson = true }
            )
            .tag(TabItem.explore)
            .tabItem {
                Label(TabItem.explore.title, systemImage: TabItem.explore.icon)
            }

            PeoplePageView(
                onAccountTap: { showAccount = true },
                onAddPerson: { showAddPerson = true }
            )
            .tag(TabItem.people)
            .tabItem {
                Label(TabItem.people.title, systemImage: TabItem.people.icon)
            }
        }
        .environment(scrollState)
        .tint(AppTheme.blue)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.spring(duration: 0.3)) {
                scrollState.reset()
            }
        }
        .fullScreenCover(isPresented: $showAddMovie) {
            ExplorePageView(
                onAccountTap: nil,
                onAddPerson: nil,
                onClose: { showAddMovie = false }
            )
            .environment(sheetScrollState)
        }
        .fullScreenCover(isPresented: $showAddPerson) {
            AddPersonFullScreenView(
                onAdded: { showAddPerson = false },
                onClose: { showAddPerson = false }
            )
        }
        .fullScreenCover(isPresented: $showAccount) {
            AccountPageView(onClose: { showAccount = false })
                .environment(sheetScrollState)
        }
    }
}

#Preview {
    RootTabHostView()
}
