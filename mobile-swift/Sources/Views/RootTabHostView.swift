import SwiftUI

// MARK: - Root Tab Host
// Custom bottom bar with tab navigation

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var scrollState = ScrollState()
    @State private var networkService = NetworkService.shared

    var body: some View {
        ZStack {
            // ── Tab Content ──
            TabView(selection: $selectedTab) {
                Tab(value: .home) { HomePageView() }
                Tab(value: .lists) { ListsPageView() }
                Tab(value: .people) { PeoplePageView() }
                Tab(value: .account) { AccountPageView() }
                Tab(value: .explore) { ExplorePageView() }
            }
            .toolbar(.hidden, for: .tabBar)
            .tint(AppTheme.blue)
            .preferredColorScheme(.dark)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .environment(scrollState)
            .onChange(of: selectedTab) { _, _ in
                withAnimation(.spring(duration: 0.3)) {
                    scrollState.reset()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        tabBarPill
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }

    // MARK: - Tab Bar Pill

    private var tabBarPill: some View {
        HStack(spacing: 4) {
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 56)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Glass Effect Modifier

extension View {
    func glassEffect(_ prominence: MaterialProminence, in shape: some InsertableShape) -> some View {
        self
            .background(AppTheme.surface, in: shape)
            .overlay {
                shape.strokeBorder(AppTheme.stroke, lineWidth: 1)
            }
    }
}

#Preview {
    RootTabHostView()
}
