import SwiftUI

// MARK: - Root Tab Host
// Native iOS 26 tab system:
// - TabView with tab bar minimize on scroll down
// - Bottom accessory search bar + add button

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var isAddMenuExpanded = false
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showAccount = false
    @State private var scrollState = ScrollState()
    @State private var searchState = SearchState()
    @State private var sheetScrollState = ScrollState()
    @State private var sheetSearchState = SearchState()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            tabHost

            if isAddMenuExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.28)) {
                            isAddMenuExpanded = false
                        }
                    }
                    .transition(.opacity)
            }

            if isAddMenuExpanded {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addMenu
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 124)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showAddMovie) {
            fullScreenSheet(onClose: { showAddMovie = false }) {
                ExplorePageView(useNativeSearch: true)
                    .environment(sheetScrollState)
                    .environment(sheetSearchState)
            }
        }
        .fullScreenCover(isPresented: $showAddPerson) {
            fullScreenSheet(onClose: { showAddPerson = false }) {
                AddPersonFullScreenView {
                    showAddPerson = false
                }
            }
        }
        .fullScreenCover(isPresented: $showAccount) {
            fullScreenSheet(onClose: { showAccount = false }) {
                AccountPageView()
                    .environment(sheetScrollState)
            }
        }
    }

    // MARK: - Native Tab Host

    private var tabHost: some View {
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
                isAddMenuExpanded: $isAddMenuExpanded,
                onAddTapped: toggleAddMenu
            )
        }
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.spring(duration: 0.3)) {
                scrollState.reset()
                isAddMenuExpanded = false
            }
        }
    }

    private func toggleAddMenu() {
        withAnimation(.spring(duration: 0.32, bounce: 0.2)) {
            isSearchFocused = false
            isAddMenuExpanded.toggle()
        }
    }

    // MARK: - Add Menu

    private var addMenu: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                quickActionRow(
                    icon: "sparkle.magnifyingglass",
                    title: "Movie",
                    subtitle: "Search TMDB and add to your collection"
                ) {
                    openAddMovie()
                }

                Rectangle()
                    .fill(AppTheme.stroke)
                    .frame(height: 1)
                    .padding(.leading, 48)

                quickActionRow(
                    icon: "person.badge.plus",
                    title: "Person",
                    subtitle: "Add a new recommender"
                ) {
                    openAddPerson()
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))

            Button {
                withAnimation(.spring(duration: 0.25)) { isAddMenuExpanded = false }
                selectedTab = .explore
            } label: {
                HStack {
                    Spacer()
                    Label("Discover", systemImage: "safari.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(width: 300)
    }

    private func quickActionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func openAddMovie() {
        withAnimation(.spring(duration: 0.25)) { isAddMenuExpanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showAddMovie = true
        }
    }

    private func openAddPerson() {
        withAnimation(.spring(duration: 0.25)) { isAddMenuExpanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showAddPerson = true
        }
    }

    private func fullScreenSheet<Content: View>(
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                content()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, proxy.safeAreaInsets.top + 8)
                .accessibilityLabel("Close")
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Bottom Accessory

private struct SearchBottomAccessory: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    @Binding var isAddMenuExpanded: Bool
    let onAddTapped: () -> Void

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

            Button(action: onAddTapped) {
                Image(systemName: isAddMenuExpanded ? "xmark" : "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAddMenuExpanded ? "Close add menu" : "Open add menu")
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

            Button(action: onAddTapped) {
                Image(systemName: isAddMenuExpanded ? "xmark" : "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAddMenuExpanded ? "Close add menu" : "Open add menu")
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
}

#Preview {
    RootTabHostView()
}
