import SwiftUI

// MARK: - Root Tab Host
// 4 tabs + a disconnected floating action button on the right side.
// The FAB expands into multiple quick-action options (compose, message, community, camera).

struct RootTabHostView: View {
    @State private var selectedTab: TabItem = .home
    @State private var isFABExpanded = false
    @State private var showCompose = false
    @State private var showNewMessage = false
    @State private var showCommunity = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ── Tab View ──
            TabView(selection: $selectedTab) {
                Tab(TabItem.home.title, systemImage: TabItem.home.icon, value: .home) {
                    HomePageView()
                }
                Tab(TabItem.inbox.title, systemImage: TabItem.inbox.icon, value: .inbox) {
                    InboxPageView()
                }
                Tab(TabItem.explore.title, systemImage: TabItem.explore.icon, value: .explore) {
                    ExplorePageView()
                }
                Tab(TabItem.profile.title, systemImage: TabItem.profile.icon, value: .profile) {
                    ProfilePageView()
                }
            }
            .tint(AppTheme.blue)
            .preferredColorScheme(.dark)
            .sensoryFeedback(.selection, trigger: selectedTab)

            // ── Dimming overlay when FAB is open ──
            if isFABExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) { isFABExpanded = false }
                    }
                    .transition(.opacity)
            }

            // ── Disconnected Floating Action Button ──
            ExpandableFAB(
                isExpanded: $isFABExpanded,
                actions: [
                    FABAction(icon: "square.and.pencil", label: "New Post", color: .blue) {
                        showCompose = true
                    },
                    FABAction(icon: "envelope.fill", label: "Message", color: .green) {
                        showNewMessage = true
                    },
                    FABAction(icon: "person.2.fill", label: "Community", color: .purple) {
                        showCommunity = true
                    },
                    FABAction(icon: "camera.fill", label: "Camera", color: .orange) {
                        // Camera action placeholder
                    }
                ]
            )
            .padding(.trailing, 20)
            .padding(.bottom, 100)
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
