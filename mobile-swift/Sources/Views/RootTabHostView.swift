import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false
    @State private var scrollState = ScrollState()
    @State private var sheetScrollState = ScrollState()

    var body: some View {
        TabView {
            Tab("Movies", systemImage: TabItem.home.icon) {
                HomePageView(
                    onAccountTap: {
                        showAccount = true
                    }
                )
            }

            Tab("People", systemImage: TabItem.people.icon) {
                PeoplePageView(
                    onAccountTap: {
                        showAccount = true
                    }
                )
            }

            Tab(role: .search) {
                GlobalSearchPageView()
            }
        }
        .environment(scrollState)
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay(alignment: .bottomTrailing) {
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
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Add options")
            .padding(.trailing, 6)
            .padding(.bottom, 84)
        }
        .sheet(isPresented: $showAddMovie) {
            AddMoviePageView(onClose: { showAddMovie = false })
            .environment(sheetScrollState)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonFullScreenView(
                onAdded: { showAddPerson = false },
                onClose: { showAddPerson = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAccount) {
            AccountPageView(onClose: { showAccount = false })
                .environment(sheetScrollState)
                .presentationDetents([.large])
        }
    }
}

#Preview {
    RootTabHostView()
}
