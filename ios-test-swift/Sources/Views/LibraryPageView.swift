import SwiftUI

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case active

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .favorites:
            return "Favorites"
        case .active:
            return "Active"
        }
    }
}

private enum LibrarySortMode: String, CaseIterable {
    case progress
    case alphabetic
}

struct LibraryPageView: View {
    @State private var searchText = ""
    @State private var filter: LibraryFilter = .all
    @State private var sortMode: LibrarySortMode = .progress
    @State private var entries = DemoData.library

    private var displayedEntries: [LibraryEntry] {
        let filtered = entries.filter { entry in
            let matchesSearch = searchText.isEmpty ||
                entry.title.localizedCaseInsensitiveContains(searchText) ||
                entry.detail.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .favorites:
                matchesFilter = entry.isFavorite
            case .active:
                matchesFilter = entry.progress < 100
            }

            return matchesSearch && matchesFilter
        }

        switch sortMode {
        case .progress:
            return filtered.sorted { $0.progress > $1.progress }
        case .alphabetic:
            return filtered.sorted { $0.title < $1.title }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(LibraryFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Collection") {
                    ForEach(displayedEntries) { entry in
                        NavigationLink {
                            LibraryDetailView(entry: entry)
                        } label: {
                            LibraryEntryRow(entry: entry)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                toggleFavorite(id: entry.id)
                            } label: {
                                Label(
                                    entry.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: entry.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                bumpProgress(id: entry.id)
                            } label: {
                                Label("Advance", systemImage: "arrow.up.circle.fill")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search modules")
            .refreshable {
                await refreshEntries()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Sort by Progress") {
                            sortMode = .progress
                        }
                        Button("Sort Alphabetically") {
                            sortMode = .alphabetic
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: filter)
        }
    }

    private func toggleFavorite(id: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isFavorite.toggle()
    }

    private func bumpProgress(id: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].progress = min(100, entries[idx].progress + 5)
    }

    private func refreshEntries() async {
        try? await Task.sleep(for: .milliseconds(700))
        entries.shuffle()
    }
}

private struct LibraryEntryRow: View {
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(entry.title, systemImage: entry.icon)
                    .font(.headline)
                Spacer()
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            Text(entry.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ProgressView(value: Double(entry.progress), total: 100)
                .tint(entry.isFavorite ? .yellow : .blue)

            Text("\(entry.progress)% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct LibraryDetailView: View {
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(entry.title, systemImage: entry.icon)
                .font(.largeTitle.bold())

            Text(entry.detail)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(entry.progress), total: 100)
                .tint(entry.isFavorite ? .yellow : .indigo)

            Spacer()
        }
        .padding()
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
