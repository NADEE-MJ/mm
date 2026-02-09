import SwiftUI

// MARK: - Root Tab Host
// Slack-style floating bottom system:
// - Main tab pill
// - Separate search button
// - Separate add button with quick actions

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
    @Namespace private var selectedTabNamespace

    var body: some View {
        ZStack {
            // ── Tab Content (manual switching) ──
            Group {
                switch selectedTab {
                case .home:
                    HomePageView {
                        showAccount = true
                    }
                case .explore:
                    ExplorePageView {
                        showAccount = true
                    }
                case .people:
                    PeoplePageView {
                        showAccount = true
                    }
                case .search:
                    SearchPageView(
                        onAccountTap: {
                            showAccount = true
                        },
                        onBackgroundTap: {
                            isSearchFocused = false
                        }
                    )
                }
            }
            .environment(scrollState)
            .environment(searchState)
            .tint(AppTheme.blue)
            .preferredColorScheme(.dark)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .onChange(of: selectedTab) { _, newTab in
                withAnimation(.spring(duration: 0.3)) {
                    scrollState.reset()
                    isAddMenuExpanded = false

                    if newTab != .search {
                        isSearchFocused = false
                        searchState.reset()
                    } else {
                        searchState.isExpanded = true
                    }
                }
            }

            // ── Dimming overlay for add menu ──
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

            // ── Add menu popover ──
            if isAddMenuExpanded {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addMenu
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 90)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Bottom controls ──
            VStack {
                Spacer()
                if selectedTab == .search {
                    searchBottomBar
                } else {
                    mainBottomBar
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
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

    // MARK: - Main Bottom Bar

    private var mainBottomBar: some View {
        HStack(spacing: 10) {
            tabBarPill
            searchButton
            addButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: selectedTab)
    }

    private var tabBarPill: some View {
        HStack(spacing: 4) {
            ForEach(TabItem.mainTabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    ZStack {
                        if selectedTab == tab {
                            Capsule()
                                .fill(AppTheme.blue.opacity(0.22))
                                .matchedGeometryEffect(
                                    id: "active-tab-background",
                                    in: selectedTabNamespace
                                )
                        }

                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(tab.title)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(
                            selectedTab == tab ? AppTheme.textPrimary : AppTheme.textSecondary
                        )
                        .frame(width: 76, height: 44)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 56)
        .glassEffect(.regular, in: .capsule)
    }

    private var searchButton: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                isAddMenuExpanded = false
                selectedTab = .search
                searchState.isExpanded = true
                searchState.searchText = ""
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isSearchFocused = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open search")
    }

    private var addButton: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if selectedTab == .search {
                    closeSearchToHome()
                }
                isAddMenuExpanded.toggle()
            }
        } label: {
            Image(systemName: isAddMenuExpanded ? "xmark" : "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open add menu")
    }

    // MARK: - Search Bottom Bar

    private var searchBottomBar: some View {
        HStack(spacing: 10) {
            if !isSearchFocused {
                Button {
                    closeSearchToHome()
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to home")
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Search", text: $searchState.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFocused = false
                    }

                if !searchState.searchText.isEmpty {
                    Button {
                        searchState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .capsule)

            Button {
                closeSearchToHome()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSearchFocused)
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

    private func closeSearchToHome() {
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            isSearchFocused = false
            searchState.reset()
            selectedTab = .home
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

#Preview {
    RootTabHostView()
}
