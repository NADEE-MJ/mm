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
            TabSection("Library") {
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
            }

            TabSection("Add") {
                Tab("Add", systemImage: "plus") {
                    AddActionsPageView(
                        onAddMovie: { showAddMovie = true },
                        onAddPerson: { showAddPerson = true }
                    )
                }
            }

            Tab(role: .search) {
                GlobalSearchPageView()
            }
        }
        .environment(scrollState)
        .tint(AppTheme.blue)
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
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

private struct AddActionsPageView: View {
    let onAddMovie: () -> Void
    let onAddPerson: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Create") {
                    Button {
                        onAddMovie()
                    } label: {
                        Label("Add Movie", systemImage: "film.fill")
                    }

                    Button {
                        onAddPerson()
                    } label: {
                        Label("Add Person", systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
