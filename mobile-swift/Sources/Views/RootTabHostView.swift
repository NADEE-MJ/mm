import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false

    var body: some View {
        TabView {
            Tab("Movies", systemImage: TabItem.home.icon) {
                HomePageView(
                    onAddMovieTap: {
                        showAddMovie = true
                    },
                    onAccountTap: {
                        showAccount = true
                    }
                )
                .tabBarMinimizeBehavior(.onScrollDown)
            }

            Tab("People", systemImage: TabItem.people.icon) {
                PeoplePageView(
                    onAddPersonTap: {
                        showAddPerson = true
                    },
                    onAccountTap: {
                        showAccount = true
                    }
                )
                .tabBarMinimizeBehavior(.onScrollDown)
            }

            Tab(role: .search) {
                GlobalSearchPageView()
                    .tabBarMinimizeBehavior(.onScrollDown)
            }
        }
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
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
        .sheet(isPresented: $showAccount) {
            AccountPageView(onClose: { showAccount = false })
                .presentationDetents([.large])
        }
    }
}

#Preview {
    RootTabHostView()
}
