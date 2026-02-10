import SwiftUI

// MARK: - Root Tab Host

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var showAddMovie = false
    @State private var showAddPerson = false
    @State private var showGlobalSearch = false
    @State private var showAccount = false
    @State private var showAddMenu = false
    @State private var scrollState = ScrollState()
    @State private var sheetScrollState = ScrollState()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomePageView(
                onAccountTap: {
                    showAddMenu = false
                    showAccount = true
                }
            )
            .tag(TabItem.home)
            .tabItem {
                Label(TabItem.home.title, systemImage: TabItem.home.icon)
            }

            PeoplePageView(
                onAccountTap: {
                    showAddMenu = false
                    showAccount = true
                }
            )
            .tag(TabItem.people)
            .tabItem {
                Label(TabItem.people.title, systemImage: TabItem.people.icon)
            }
        }
        .environment(scrollState)
        .tint(AppTheme.blue)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.spring(duration: 0.3)) {
                scrollState.reset()
                showAddMenu = false
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingQuickActions(
                isExpanded: $showAddMenu,
                onToggleAddMenu: {
                    withAnimation(.spring(duration: 0.28)) {
                        showAddMenu.toggle()
                    }
                },
                onOpenSearch: {
                    showAddMenu = false
                    showGlobalSearch = true
                },
                onAddMovie: {
                    showAddMenu = false
                    showAddMovie = true
                },
                onAddPerson: {
                    showAddMenu = false
                    showAddPerson = true
                }
            )
            .padding(.trailing, 8)
            .padding(.bottom, 76)
            .offset(x: 10)
        }
        .sheet(isPresented: $showAddMovie) {
            AddMoviePageView(onClose: { showAddMovie = false })
            .environment(sheetScrollState)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonFullScreenView(
                onAdded: { showAddPerson = false },
                onClose: { showAddPerson = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showGlobalSearch) {
            GlobalSearchPageView(onClose: { showGlobalSearch = false })
                .environment(sheetScrollState)
        }
        .fullScreenCover(isPresented: $showAccount) {
            AccountPageView(onClose: { showAccount = false })
                .environment(sheetScrollState)
        }
    }
}

#Preview {
    RootTabHostView()
}

private struct FloatingQuickActions: View {
    @Binding var isExpanded: Bool
    let onToggleAddMenu: () -> Void
    let onOpenSearch: () -> Void
    let onAddMovie: () -> Void
    let onAddPerson: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isExpanded {
                VStack(alignment: .trailing, spacing: 10) {
                    expandedActionButton(
                        title: "Add Movie",
                        icon: "film.fill",
                        tint: AppTheme.blue,
                        action: onAddMovie
                    )
                    expandedActionButton(
                        title: "Add Person",
                        icon: "person.badge.plus",
                        tint: .green,
                        action: onAddPerson
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            circleButton(
                icon: isExpanded ? "xmark" : "plus",
                tint: AppTheme.blue,
                accessibilityLabel: isExpanded ? "Close add menu" : "Open add menu",
                action: onToggleAddMenu
            )

            circleButton(
                icon: "magnifyingglass",
                tint: .orange,
                accessibilityLabel: "Open global search",
                action: onOpenSearch
            )
        }
    }

    private func expandedActionButton(
        title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.32), lineWidth: 1)
            )
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.26), radius: 8, x: 0, y: 5)
    }

    private func circleButton(
        icon: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.36), lineWidth: 1.3)
                )
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .accessibilityLabel(accessibilityLabel)
    }
}
