import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showGlobalSearch = false
    @State private var showAccount = false
    @State private var scrollState = ScrollState()
    @State private var sheetScrollState = ScrollState()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomePageView(
                onAccountTap: {
                    showAccount = true
                }
            )
            .tag(TabItem.home)
            .tabItem {
                Label(TabItem.home.title, systemImage: TabItem.home.icon)
            }

            PeoplePageView(
                onAccountTap: {
                    showAccount = true
                }
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
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Menu {
                        Button {
                            showAddMovie = true
                        } label: {
                            Label("Add Movie", systemImage: "film.fill")
                        }

                        Button {
                            showAddPerson = true
                        } label: {
                            Label("Add Person", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel("Add options")

                    Button {
                        showGlobalSearch = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Open global search")
                }
                .padding(.trailing, 12)
                .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showAddMovie) {
            AddMoviePageView(onClose: { showAddMovie = false })
            .environment(sheetScrollState)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonFullScreenView(
                onAdded: { showAddPerson = false },
                onClose: { showAddPerson = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showGlobalSearch) {
            GlobalSearchPageView(onClose: { showGlobalSearch = false })
                .environment(sheetScrollState)
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
