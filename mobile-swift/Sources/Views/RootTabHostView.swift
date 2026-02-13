import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    private enum RootTab: Hashable {
        case movies
        case people
        case add
        case account
    }

    @State private var selectedTab: RootTab = .movies
    @State private var wsManager = WebSocketManager.shared
    @State private var repository = MovieRepository.shared
    @State private var discoverNavigation = DiscoverNavigationState.shared
    @State private var pendingOfflineCount = 0
    @State private var showPendingResolutionPrompt = false
    @State private var hasCheckedPendingOnLaunch = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Movies", systemImage: TabItem.home.icon, value: RootTab.movies) {
                HomePageView()
            }

            Tab("People", systemImage: TabItem.people.icon, value: RootTab.people) {
                PeoplePageView()
            }

            Tab("Discover", systemImage: "plus", value: RootTab.add) {
                AddMoviePageView()
            }

            Tab("Account", systemImage: "person.crop.circle", value: RootTab.account) {
                AccountPageView()
            }
        }
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            guard !hasCheckedPendingOnLaunch else { return }
            hasCheckedPendingOnLaunch = true
            refreshPendingMovies(shouldPrompt: true)
        }
        .onChange(of: wsManager.updateEventCounter) { _, _ in
            refreshPendingMovies(shouldPrompt: true)
        }
        .onChange(of: discoverNavigation.requestId) { _, _ in
            selectedTab = .add
        }
        .alert("Resolve Offline Movies", isPresented: $showPendingResolutionPrompt) {
            Button("Review Now") {
                selectedTab = .add
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text(
                "You have \(pendingOfflineCount) queued offline movie\(pendingOfflineCount == 1 ? "" : "s") waiting for a match."
            )
        }
    }

    private func refreshPendingMovies(shouldPrompt: Bool) {
        pendingOfflineCount = repository.fetchPendingMovies().count
        guard shouldPrompt else { return }
        guard pendingOfflineCount > 0 else { return }
        showPendingResolutionPrompt = true
    }
}

#Preview {
    RootTabHostView()
}
