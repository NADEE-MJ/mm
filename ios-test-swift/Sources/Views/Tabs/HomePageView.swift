import SwiftUI

// MARK: - Home Page
// Features: search, swipe actions (favorite / delete), context menus with peek preview,
// confirmation dialog, pull-to-refresh, working navigation links.

struct HomePageView: View {
    @State private var workItems = DemoData.workRows
    @State private var showingComposer = false
    @State private var itemToDelete: WorkRow?
    @State private var showDeleteAlert = false
    @State private var searchText = ""

    private var filteredItems: [WorkRow] {
        if searchText.isEmpty { return workItems }
        return workItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var favorites: [WorkRow] {
        workItems.filter(\.isFavorite)
    }

    var body: some View {
        NavigationStack {
            List {
                // ── My Work ──
                Section("My Work") {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            DetailView(title: item.title, icon: item.icon)
                        } label: {
                            workRow(item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { toggleFavorite(item) } label: {
                                Label(
                                    item.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: item.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .contextMenu {
                            Button { } label: { Label("Copy Link", systemImage: "doc.on.doc") }
                            Button { } label: { Label("Share", systemImage: "square.and.arrow.up") }
                            Button { toggleFavorite(item) } label: {
                                Label(
                                    item.isFavorite ? "Remove Favorite" : "Favorite",
                                    systemImage: item.isFavorite ? "star.slash" : "star"
                                )
                            }
                            Divider()
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } preview: {
                            DetailView(title: item.title, icon: item.icon)
                                .frame(width: 320, height: 420)
                        }
                    }
                }

                // ── Favorites ──
                if !favorites.isEmpty {
                    Section("⭐ Favorites") {
                        ForEach(favorites) { item in
                            NavigationLink {
                                DetailView(title: item.title, icon: item.icon)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.icon)
                                        .foregroundStyle(.yellow)
                                        .frame(width: 24)
                                    Text(item.title)
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                    }
                }

                // ── Agents & CI ──
                Section("Agents & CI") {
                    NavigationLink {
                        DetailView(title: "Copilot Sessions", icon: "sparkle")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkle")
                                .foregroundStyle(.purple)
                                .frame(width: 24)
                            Text("Copilot Sessions")
                            Spacer()
                            Text("3 active")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    NavigationLink {
                        DetailView(title: "Workflows", icon: "bolt.fill")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            Text("Workflows")
                            Spacer()
                            Text("All passing")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    NavigationLink {
                        DetailView(title: "Deployments", icon: "cloud.fill")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cloud.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text("Deployments")
                            Spacer()
                            Text("2 live")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { PageBackground() }
            .navigationTitle("Home")
            .searchable(text: $searchText, prompt: "Search work items…")
            .refreshable {
                try? await Task.sleep(for: .milliseconds(800))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingComposer = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                AddWorkItemSheet(workItems: $workItems)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .alert("Delete \(itemToDelete?.title ?? "")?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        withAnimation { workItems.removeAll { $0.id == item.id } }
                    }
                    itemToDelete = nil
                }
                Button("Cancel", role: .cancel) { itemToDelete = nil }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Helpers

    private func workRow(_ item: WorkRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(AppTheme.blue)
                .frame(width: 24)
            Text(item.title)
            Spacer()
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption).foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }

    private func toggleFavorite(_ item: WorkRow) {
        if let idx = workItems.firstIndex(where: { $0.id == item.id }) {
            withAnimation { workItems[idx].isFavorite.toggle() }
        }
    }
}

// MARK: - Add Work Item Sheet

private struct AddWorkItemSheet: View {
    @Binding var workItems: [WorkRow]
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedIcon = "star.fill"

    private let icons = [
        "star.fill", "heart.fill", "bookmark.fill", "flag.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "globe"
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)

                Section("Icon") {
                    LazyVGrid(columns: [.init(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedIcon == icon ? AppTheme.blue.opacity(0.25) : Color.clear,
                                        in: .rect(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("New Item")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = WorkRow(
                            id: UUID().uuidString,
                            title: title,
                            icon: selectedIcon
                        )
                        withAnimation { workItems.insert(item, at: 0) }
                        dismiss()
                    }
                    .bold()
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
