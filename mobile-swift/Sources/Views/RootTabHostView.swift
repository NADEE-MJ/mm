import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false
    @State private var isSearchTabActive = false

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
                    .onAppear { isSearchTabActive = true }
                    .onDisappear { isSearchTabActive = false }
            }
        }
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if !isSearchTabActive {
                HStack {
                    Spacer()

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
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Add options")
                }
                .padding(.trailing, 6)
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
        .sheet(isPresented: $showAccount) {
            AccountPageView(onClose: { showAccount = false })
                .presentationDetents([.large])
        }
    }
}

#Preview {
    RootTabHostView()
}
