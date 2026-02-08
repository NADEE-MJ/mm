import SwiftUI

// MARK: - Root Tab Host
// Custom bottom bar: tab pill (left) + FAB (right).
// Both collapse/minimize when the user scrolls down.

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var isFABExpanded = false
    @State private var showCompose = false
    @State private var showNewMessage = false
    @State private var showCommunity = false
    @State private var scrollState = ScrollState()

    private var isMinimized: Bool { scrollState.isMinimized }

    var body: some View {
        ZStack {
            // ── Tab Content ──
            TabView(selection: $selectedTab) {
                Tab(value: .home) { HomePageView() }
                Tab(value: .inbox) { InboxPageView() }
                Tab(value: .explore) { ExplorePageView() }
                Tab(value: .profile) { ProfilePageView() }
            }
            .toolbar(.hidden, for: .tabBar)
            .tint(AppTheme.blue)
            .preferredColorScheme(.dark)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .environment(scrollState)
            .onChange(of: selectedTab) { _, _ in
                withAnimation(.spring(duration: 0.3)) {
                    scrollState.reset()
                    if isFABExpanded { isFABExpanded = false }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }

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
        // ── Sheets & Covers ──
        .sheet(isPresented: $showCompose) {
            ComposeSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $showCommunity) {
            NavigationStack {
                CommunityPageView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showCommunity = false }
                        }
                    }
            }
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 12) {
            tabBarPill
            Spacer()
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
                // Collapsed: show only the current tab
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
                        .frame(width: 60, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, isMinimized ? 10 : 12)
        .padding(.vertical, isMinimized ? 6 : 6)
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
            FABAction(icon: "square.and.pencil", label: "New Post", color: .blue) { showCompose = true },
            FABAction(icon: "envelope.fill", label: "Message", color: .green) { showNewMessage = true },
            FABAction(icon: "person.2.fill", label: "Community", color: .purple) { showCommunity = true },
            FABAction(icon: "camera.fill", label: "Camera", color: .orange) { }
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
}

// MARK: - Compose Sheet (segmented type picker, multiline text, attachment buttons)

private struct ComposeSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedType = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Type", selection: $selectedType) {
                    Text("Post").tag(0)
                    Text("Question").tag(1)
                    Text("Link").tag(2)
                }
                .pickerStyle(.segmented)

                TextField("What's on your mind?", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                HStack(spacing: 12) {
                    Button { } label: { Label("Photo", systemImage: "photo") }
                        .buttonStyle(.bordered).tint(AppTheme.blue)
                    Button { } label: { Label("Link", systemImage: "link") }
                        .buttonStyle(.bordered).tint(AppTheme.blue)
                    Spacer()
                }

                Spacer()
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle("New Post")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { dismiss() }
                        .bold().disabled(text.isEmpty)
                }
            }
        }
    }
}

// MARK: - New Message Sheet

private struct NewMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("To:", text: $recipient)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                TextField("Message…", text: $message, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                Spacer()
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle("New Message")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { dismiss() }
                        .bold().disabled(message.isEmpty)
                }
            }
        }
    }
}

#Preview {
    RootTabHostView()
}
