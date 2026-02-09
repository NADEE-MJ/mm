import SwiftUI

// MARK: - Root Tab Host
// Native iOS 26 tab system:
// - TabView with tab bar minimize on scroll down
// - Bottom accessory search bar + add menu

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false
    @State private var scrollState = ScrollState()
    @State private var searchState = SearchState()
    @State private var sheetScrollState = ScrollState()
    @State private var sheetSearchState = SearchState()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        TabView(selection: $selectedTab) {
            HomePageView {
                showAccount = true
            }
            .tag(TabItem.home)
            .tabItem {
                Label(TabItem.home.title, systemImage: TabItem.home.icon)
            }

            ExplorePageView {
                showAccount = true
            }
            .tag(TabItem.explore)
            .tabItem {
                Label(TabItem.explore.title, systemImage: TabItem.explore.icon)
            }

            PeoplePageView {
                showAccount = true
            }
            .tag(TabItem.people)
            .tabItem {
                Label(TabItem.people.title, systemImage: TabItem.people.icon)
            }
        }
        .environment(scrollState)
        .environment(searchState)
        .tint(AppTheme.blue)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            SearchBottomAccessory(
                searchText: $searchState.searchText,
                isSearchFocused: $isSearchFocused,
                onAddMovie: openAddMovie,
                onAddPerson: openAddPerson
            )
        }
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.spring(duration: 0.3)) {
                scrollState.reset()
            }
        }
        .fullScreenCover(isPresented: $showAddMovie) {
            ExplorePageView(
                onAccountTap: nil,
                useNativeSearch: true,
                onClose: { showAddMovie = false }
            )
            .environment(sheetScrollState)
            .environment(sheetSearchState)
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

    private func openAddMovie() {
        isSearchFocused = false
        showAddMovie = true
    }

    private func openAddPerson() {
        isSearchFocused = false
        showAddPerson = true
    }
}

// MARK: - Bottom Accessory

private struct SearchBottomAccessory: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let onAddMovie: () -> Void
    let onAddPerson: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Group {
            switch placement {
            case .inline:
                inlineAccessory
            case .expanded:
                expandedAccessory
            default:
                expandedAccessory
            }
        }
    }

    private var expandedAccessory: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .capsule)

            addMenuButton(size: 48, iconSize: 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var inlineAccessory: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Text(searchText.isEmpty ? "Search" : searchText)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(searchText.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)

            Spacer()

            addMenuButton(size: 28, iconSize: 15)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = true
        }
    }

    private func addMenuButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Menu {
            Button {
                onAddMovie()
            } label: {
                Label("Movie", systemImage: "sparkle.magnifyingglass")
            }

            Button {
                onAddPerson()
            } label: {
                Label("Person", systemImage: "person.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(size < 40 ? AppTheme.textPrimary : .white)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuIndicator(.hidden)
        .accessibilityLabel("Add")
    }
}

#Preview {
    RootTabHostView()
}
