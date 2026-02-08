import SwiftUI

// MARK: - Inbox Page
// Features: searchable with scopes, swipe to delete / archive / mark-read,
// context menus, pull-to-refresh, filter menu in toolbar, empty state.

struct InboxPageView: View {
    @State private var threads = DemoData.inboxThreads
    @State private var searchText = ""
    @State private var selectedScope: InboxScope = .all
    @Environment(ScrollState.self) private var scrollState

    private enum InboxScope: String, CaseIterable, Hashable {
        case all = "All"
        case unread = "Unread"
        case archived = "Archived"
    }

    private var filteredThreads: [InboxThread] {
        var result = threads

        switch selectedScope {
        case .all:       result = result.filter { !$0.isArchived }
        case .unread:    result = result.filter { $0.unreadCount > 0 && !$0.isArchived }
        case .archived:  result = result.filter { $0.isArchived }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.subtitle.localizedCaseInsensitiveContains(searchText) ||
                $0.sender.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredThreads.isEmpty {
                    ContentUnavailableView(
                        "No Messages",
                        systemImage: "tray",
                        description: Text(selectedScope == .archived
                            ? "No archived messages yet."
                            : "All caught up! 🎉")
                    )
                } else {
                    List {
                        ForEach(filteredThreads) { thread in
                            ThreadRow(thread: thread)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { deleteThread(thread) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { archiveThread(thread) } label: {
                                        Label(
                                            thread.isArchived ? "Unarchive" : "Archive",
                                            systemImage: thread.isArchived ? "tray.and.arrow.down" : "archivebox"
                                        )
                                    }
                                    .tint(.orange)

                                    Button { markRead(thread) } label: {
                                        Label("Read", systemImage: "envelope.open")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button { markRead(thread) } label: {
                                        Label("Mark as Read", systemImage: "envelope.open")
                                    }
                                    Button { archiveThread(thread) } label: {
                                        Label(thread.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                                    }
                                    Button { } label: {
                                        Label("Mute Thread", systemImage: "bell.slash")
                                    }
                                    Divider()
                                    Button(role: .destructive) { deleteThread(thread) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.y
                    } action: { _, offset in
                        withAnimation(.spring(duration: 0.35)) {
                            scrollState.update(offset: offset)
                        }
                    }
                }
            }
            .background { PageBackground() }
            .navigationTitle("Inbox")
            .searchable(text: $searchText, prompt: "Search messages…")
            .searchScopes($selectedScope, activation: .onSearchPresentation) {
                ForEach(InboxScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue)
                }
            }
            .refreshable {
                try? await Task.sleep(for: .milliseconds(600))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { withAnimation { selectedScope = .all } } label: {
                            Label("All", systemImage: "tray.full")
                        }
                        Button { withAnimation { selectedScope = .unread } } label: {
                            Label("Unread Only", systemImage: "envelope.badge")
                        }
                        Button { withAnimation { selectedScope = .archived } } label: {
                            Label("Archived", systemImage: "archivebox")
                        }
                        Divider()
                        Button { markAllRead() } label: {
                            Label("Mark All Read", systemImage: "envelope.open.fill")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteThread(_ thread: InboxThread) {
        withAnimation { threads.removeAll { $0.id == thread.id } }
    }

    private func archiveThread(_ thread: InboxThread) {
        if let idx = threads.firstIndex(where: { $0.id == thread.id }) {
            withAnimation { threads[idx].isArchived.toggle() }
        }
    }

    private func markRead(_ thread: InboxThread) {
        if let idx = threads.firstIndex(where: { $0.id == thread.id }) {
            withAnimation { threads[idx].unreadCount = 0 }
        }
    }

    private func markAllRead() {
        withAnimation {
            for idx in threads.indices { threads[idx].unreadCount = 0 }
        }
    }
}

// MARK: - Thread Row

private struct ThreadRow: View {
    let thread: InboxThread

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(thread.unreadCount > 0 ? AppTheme.blue : AppTheme.surfaceMuted)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(thread.timestamp)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Text(thread.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                HStack {
                    Text(thread.sender)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                    Spacer()
                    BadgeView(count: thread.unreadCount)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
