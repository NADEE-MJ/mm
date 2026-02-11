import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    private enum RootTab: Hashable {
        case movies
        case people
        case add
    }

    @State private var selectedTab: RootTab = .movies
    @State private var lastContentTab: RootTab = .movies

    @State private var movieSearchText = ""
    @State private var peopleSearchText = ""

    @State private var movieFilterTrigger = 0
    @State private var peopleFilterTrigger = 0

    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false

    @State private var isSearchEditing = false
    @FocusState private var isKeyboardSearchFocused: Bool

    private var activeSearchPlaceholder: String {
        switch currentContentTab {
        case .movies:
            return "Search movies"
        case .people:
            return "Search people"
        case .add:
            return "Search"
        }
    }

    private var activeSearchBinding: Binding<String> {
        Binding(
            get: {
                switch currentContentTab {
                case .movies:
                    return movieSearchText
                case .people:
                    return peopleSearchText
                case .add:
                    return movieSearchText
                }
            },
            set: { newValue in
                switch currentContentTab {
                case .movies:
                    movieSearchText = newValue
                case .people:
                    peopleSearchText = newValue
                case .add:
                    movieSearchText = newValue
                }
            }
        )
    }

    private var currentContentTab: RootTab {
        selectedTab == .add ? lastContentTab : selectedTab
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Movies", systemImage: TabItem.home.icon, value: RootTab.movies) {
                HomePageView(
                    searchText: movieSearchText,
                    filterTrigger: movieFilterTrigger,
                    onAccountTap: {
                        showAccount = true
                    }
                )
            }

            Tab("People", systemImage: TabItem.people.icon, value: RootTab.people) {
                PeoplePageView(
                    searchText: peopleSearchText,
                    filterTrigger: peopleFilterTrigger,
                    onAccountTap: {
                        showAccount = true
                    }
                )
            }

            Tab("Add", systemImage: "plus", value: RootTab.add, role: .search) {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .tint(AppTheme.blue)
        .tabBarMinimizeBehavior(.onScroll)
        .tabViewBottomAccessory(isEnabled: !isSearchEditing) {
            bottomAccessory
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if isSearchEditing {
                keyboardSearchAccessory
            }
        }
        .animation(.snappy, value: isSearchEditing)
        .onChange(of: selectedTab) { oldValue, newValue in
            switch newValue {
            case .movies, .people:
                lastContentTab = newValue
            case .add:
                let sourceTab = oldValue == .add ? lastContentTab : oldValue
                triggerAddFlow(for: sourceTab)
                selectedTab = sourceTab
            }
        }
        .onChange(of: isKeyboardSearchFocused) { _, focused in
            if !focused, isSearchEditing {
                endSearchEditing()
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

    private var bottomAccessory: some View {
        HStack(spacing: 10) {
            Button {
                beginSearchEditing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(activeSearchBinding.wrappedValue.isEmpty ? activeSearchPlaceholder : activeSearchBinding.wrappedValue)
                        .foregroundStyle(activeSearchBinding.wrappedValue.isEmpty ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeSearchPlaceholder)

            filterButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var keyboardSearchAccessory: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(activeSearchPlaceholder, text: activeSearchBinding)
                    .focused($isKeyboardSearchFocused)
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

            filterButton
        }
        .padding(.horizontal, 12)
        .task {
            isKeyboardSearchFocused = true
        }
    }

    private var filterButton: some View {
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
    }

    private func triggerFilterSheet() {
        endSearchEditing()
        switch currentContentTab {
        case .movies:
            movieFilterTrigger += 1
        case .people:
            peopleFilterTrigger += 1
        case .add:
            break
        }
    }

    private func triggerAddFlow(for tab: RootTab) {
        endSearchEditing()
        switch tab {
        case .movies:
            showAddMovie = true
        case .people:
            showAddPerson = true
        case .add:
            showAddMovie = true
        }
    }

    private func beginSearchEditing() {
        isSearchEditing = true
    }

    private func endSearchEditing() {
        isKeyboardSearchFocused = false
        isSearchEditing = false
    }
}

#Preview {
    RootTabHostView()
}
