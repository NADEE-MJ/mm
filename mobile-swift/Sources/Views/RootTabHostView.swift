import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home

    @State private var movieSearchText = ""
    @State private var peopleSearchText = ""

    @State private var movieFilterTrigger = 0
    @State private var peopleFilterTrigger = 0

    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false

    private var activeSearchPlaceholder: String {
        switch selectedTab {
        case .home:
            return "Search movies"
        case .people:
            return "Search people"
        }
    }

    private var activeSearchBinding: Binding<String> {
        Binding(
            get: {
                switch selectedTab {
                case .home:
                    return movieSearchText
                case .people:
                    return peopleSearchText
                }
            },
            set: { newValue in
                switch selectedTab {
                case .home:
                    movieSearchText = newValue
                case .people:
                    peopleSearchText = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Movies", systemImage: TabItem.home.icon, value: TabItem.home) {
                HomePageView(
                    searchText: movieSearchText,
                    filterTrigger: movieFilterTrigger,
                    onAccountTap: {
                        showAccount = true
                    }
                )
            }

            Tab("People", systemImage: TabItem.people.icon, value: TabItem.people) {
                PeoplePageView(
                    searchText: peopleSearchText,
                    filterTrigger: peopleFilterTrigger,
                    onAccountTap: {
                        showAccount = true
                    }
                )
            }
        }
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            bottomAccessory
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

    private var bottomAccessory: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(activeSearchPlaceholder, text: activeSearchBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !activeSearchBinding.wrappedValue.isEmpty {
                    Button {
                        activeSearchBinding.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())

            Button {
                triggerFilterSheet()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .clipShape(Circle())
            .accessibilityLabel("Sort and filter")

            Button {
                triggerAddFlow()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.blue, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedTab == .home ? "Add movie" : "Add person")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func triggerFilterSheet() {
        switch selectedTab {
        case .home:
            movieFilterTrigger += 1
        case .people:
            peopleFilterTrigger += 1
        }
    }

    private func triggerAddFlow() {
        switch selectedTab {
        case .home:
            showAddMovie = true
        case .people:
            showAddPerson = true
        }
    }
}

#Preview {
    RootTabHostView()
}
