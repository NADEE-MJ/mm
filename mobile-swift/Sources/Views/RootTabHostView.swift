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
    @State private var lastContentTab: RootTab = .movies

    @State private var showAddMovie = false
    @State private var showAddPerson = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Movies", systemImage: TabItem.home.icon, value: RootTab.movies) {
                HomePageView()
            }

            Tab("People", systemImage: TabItem.people.icon, value: RootTab.people) {
                PeoplePageView()
            }

            Tab("Add", systemImage: "plus", value: RootTab.add, role: .search) {
                Color.clear
                    .accessibilityHidden(true)
            }

            Tab("Account", systemImage: "person.crop.circle", value: RootTab.account) {
                AccountPageView()
            }
        }
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { oldValue, newValue in
            switch newValue {
            case .movies, .people, .account:
                lastContentTab = newValue
            case .add:
                let sourceTab = oldValue == .add ? lastContentTab : oldValue
                triggerAddFlow(for: sourceTab)
                selectedTab = sourceTab
            }
        }
        .sheet(isPresented: $showAddMovie) {
            AddMoviePageView(onClose: { showAddMovie = false })
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonFullScreenView(
                onAdded: { showAddPerson = false },
                onClose: { showAddPerson = false }
            )
            .presentationDetents([.large])
        }
    }

    private func triggerAddFlow(for tab: RootTab) {
        switch tab {
        case .movies, .account:
            showAddMovie = true
        case .people:
            showAddPerson = true
        case .add:
            showAddMovie = true
        }
    }
}

#Preview {
    RootTabHostView()
}
