import SwiftUI

// MARK: - Root Tab Host
// Custom bottom bar: collapsible tab pill + FAB.
// Uses manual view switching instead of TabView to avoid
// native tab bar conflicts on iOS 26.

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var isFABExpanded = false
    @State private var showAddMovie = false
    @State private var scrollState = ScrollState()
    @State private var sheetScrollState = ScrollState()
    @State private var searchState = SearchState()
    @FocusState private var isSearchFocused: Bool

    private var isMinimized: Bool { scrollState.isMinimized }

    var body: some View {
        ZStack {
            // ── Tab Content (manual switching) ──
            Group {
                switch selectedTab {
                case .home:
                    HomePageView()
                case .explore:
                    ExplorePageView()
                case .people:
                    PeoplePageView()
                case .account:
                    AccountPageView()
                }
            }
            .environment(scrollState)
            .environment(searchState)
            .tint(AppTheme.blue)
            .preferredColorScheme(.dark)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .onChange(of: selectedTab) { _, _ in
                withAnimation(.spring(duration: 0.3)) {
                    scrollState.reset()
                    searchState.reset()
                    isSearchFocused = false
                    if isFABExpanded { isFABExpanded = false }
                }
            }

            // ── Bottom bar (floating overlay) ──
            VStack {
                Spacer()
                
                // Expandable Search Bar (above tab bar)
                if searchState.isExpanded {
                    expandableSearchBar
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .padding(.bottom, 8)
                }
                
                bottomBar
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // ── Dimming overlay ──
            if isFABExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) { isFABExpanded = false }
                    }
                    .transition(.opacity)
            }

            // ── Expanded FAB actions ──
            if isFABExpanded {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 12) {
                            ForEach(Array(fabActions.enumerated()), id: \.offset) { index, action in
                                fabActionRow(action, index: index)
                                    .transition(
                                        .asymmetric(
                                            insertion: .scale(scale: 0.4).combined(with: .opacity),
                                            removal: .scale(scale: 0.6).combined(with: .opacity)
                                        )
                                    )
                            }
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, isMinimized ? 56 : 72)
            }
        }
        .sheet(isPresented: $showAddMovie) {
            NavigationStack {
                ExplorePageView()
                    .environment(sheetScrollState)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showAddMovie = false }
                        }
                    }
            }
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 8) {
            tabBarPill
            Spacer()
            searchButton
            fabMainButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .animation(.spring(duration: 0.35), value: isMinimized)
    }

    // MARK: - Tab Bar Pill

    private var tabBarPill: some View {
        HStack(spacing: isMinimized ? 0 : 4) {
            if isMinimized {
                // Collapsed: show only the current tab icon
                Image(systemName: selectedTab.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 28, height: 28)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.title)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(selectedTab == tab ? AppTheme.blue : AppTheme.textSecondary)
                        .frame(width: 64, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, isMinimized ? 10 : 12)
        .padding(.vertical, 6)
        .frame(height: isMinimized ? 40 : 56)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - FAB Main Button

    private var fabMainButton: some View {
        let size: CGFloat = isMinimized ? 40 : 56
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                isFABExpanded.toggle()
            }
        } label: {
            Image(systemName: isFABExpanded ? "xmark" : "plus")
                .font(.system(size: isMinimized ? 16 : 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    isFABExpanded ? Color.gray : AppTheme.blue,
                    in: .circle
                )
                .shadow(
                    color: (isFABExpanded ? Color.gray : AppTheme.blue).opacity(0.35),
                    radius: 8, y: 3
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .solid), trigger: isFABExpanded)
    }

    // MARK: - FAB Actions

    private var fabActions: [FABAction] {
        [
            FABAction(icon: "sparkle.magnifyingglass", label: "Add Movie", color: .blue) {
                showAddMovie = true
            },
            FABAction(icon: "person.badge.plus", label: "Add Person", color: .green) {
                selectedTab = .people
            },
        ]
    }

    private func fabActionRow(_ item: FABAction, index: Int) -> some View {
        HStack(spacing: 10) {
            Text(item.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)

            Button {
                item.action()
                withAnimation(.spring(duration: 0.3)) {
                    isFABExpanded = false
                }
            } label: {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(item.color, in: .circle)
                    .shadow(color: item.color.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Search Button
    
    private var searchButton: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                searchState.isExpanded.toggle()
                if searchState.isExpanded {
                    isSearchFocused = true
                } else {
                    searchState.searchText = ""
                    isSearchFocused = false
                }
            }
        } label: {
            Image(systemName: searchState.isExpanded ? "xmark.circle" : "magnifyingglass")
                .font(.system(size: isMinimized ? 16 : 20, weight: .semibold))
                .foregroundStyle(searchState.isExpanded ? AppTheme.textSecondary : AppTheme.blue)
                .frame(width: isMinimized ? 36 : 44, height: isMinimized ? 36 : 44)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: searchState.isExpanded)
    }
    
    // MARK: - Expandable Search Bar
    
    private var expandableSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                TextField("Search movies...", text: $searchState.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                
                if !searchState.searchText.isEmpty {
                    Button {
                        searchState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - FAB Action Model

private struct FABAction {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

#Preview {
    RootTabHostView()
}
