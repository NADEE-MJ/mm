import SwiftUI

// MARK: - People Page

struct PeoplePageView: View {
    enum TrustedFilter: String, CaseIterable {
        case all = "All"
        case trusted = "Trusted"
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case mostMovies = "Most Movies"
        case trustedFirst = "Trusted First"

        var id: String { rawValue }
    }

    var onAccountTap: (() -> Void)? = nil

    @State private var people: [Person] = []
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var filter: TrustedFilter = .all
    @State private var sortBy: SortOption = .name
    @State private var showFilters = false

    private var filteredPeople: [Person] {
        var result = people

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
        }

        if filter == .trusted {
            result = result.filter { $0.isTrusted }
        }

        return sortedPeople(result)
    }

    private var trustedCount: Int {
        people.filter(\.isTrusted).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if filteredPeople.isEmpty {
                        ContentUnavailableView(
                            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No People" : "No Results",
                            systemImage: "person.2.slash",
                            description: Text(
                                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Add people to track who suggests movies."
                                    : "Try a different search term or clear filters."
                            )
                        )
                    } else {
                        ForEach(filteredPeople) { person in
                            NavigationLink {
                                PersonDetailView(person: person) {
                                    await loadPeople()
                                }
                            } label: {
                                PersonRow(person: person)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task {
                                        await NetworkService.shared.updatePerson(
                                            name: person.name,
                                            isTrusted: !person.isTrusted
                                        )
                                        await loadPeople()
                                    }
                                } label: {
                                    Label(
                                        person.isTrusted ? "Mark Untrusted" : "Mark Trusted",
                                        systemImage: person.isTrusted ? "star.slash.fill" : "star.fill"
                                    )
                                }
                                .tint(person.isTrusted ? .orange : .green)
                            }
                            .contextMenu {
                                Button {
                                    Task {
                                        await NetworkService.shared.updatePerson(
                                            name: person.name,
                                            isTrusted: !person.isTrusted
                                        )
                                        await loadPeople()
                                    }
                                } label: {
                                    Label(
                                        person.isTrusted ? "Mark Untrusted" : "Mark Trusted",
                                        systemImage: person.isTrusted ? "star.slash.fill" : "star.fill"
                                    )
                                }
                            }
                        }
                    }
                } header: {
                    Text("\(filteredPeople.count) people")
                } footer: {
                    Text("Swipe right or use the context menu to toggle trust.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: "Search people"
            )
            .refreshable {
                await loadPeople()
            }
            .task {
                await loadPeople()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search people")

                    Button {
                        isSearchPresented = false
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Sort and filter")

                    if let onAccountTap {
                        Button(action: onAccountTap) {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Open account")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                PeopleFilterSortSheet(
                    sortBy: $sortBy,
                    filter: $filter,
                    totalPeopleCount: people.count,
                    trustedCount: trustedCount
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func loadPeople() async {
        await NetworkService.shared.fetchPeople()
        people = NetworkService.shared.people
    }

    private func sortedPeople(_ input: [Person]) -> [Person] {
        switch sortBy {
        case .name:
            return input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostMovies:
            return input.sorted {
                if $0.movieCount == $1.movieCount {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.movieCount > $1.movieCount
            }
        case .trustedFirst:
            return input.sorted {
                if $0.isTrusted != $1.isTrusted {
                    return $0.isTrusted && !$1.isTrusted
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}

// MARK: - People Filter/Sort Sheet

private struct PeopleFilterSortSheet: View {
    @Binding var sortBy: PeoplePageView.SortOption
    @Binding var filter: PeoplePageView.TrustedFilter
    let totalPeopleCount: Int
    let trustedCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    Picker("Sort By", selection: $sortBy) {
                        ForEach(PeoplePageView.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Filter") {
                    Picker("People", selection: $filter) {
                        Text("All (\(totalPeopleCount))").tag(PeoplePageView.TrustedFilter.all)
                        Text("Trusted (\(trustedCount))").tag(PeoplePageView.TrustedFilter.trusted)
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button("Reset", role: .destructive) {
                        sortBy = .name
                        filter = .all
                    }
                }
            }
            .navigationTitle("Sort and Filter")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Person Row

private struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: person.isTrusted ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .font(.title3)
                .foregroundStyle(person.isTrusted ? .yellow : AppTheme.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.headline)

                Text("\(person.movieCount) movie\(person.movieCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if person.isTrusted {
                Label("Trusted", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Person Detail View

private struct PersonDetailView: View {
    let person: Person
    let onUpdate: () async -> Void
    @State private var isTrusted: Bool

    init(person: Person, onUpdate: @escaping () async -> Void) {
        self.person = person
        self.onUpdate = onUpdate
        _isTrusted = State(initialValue: person.isTrusted)
    }

    var body: some View {
        Form {
            Section("Profile") {
                LabeledContent("Name") {
                    Text(person.name)
                }
                LabeledContent("Recommendations") {
                    Text("\(person.movieCount)")
                }
            }

            Section("Trust") {
                Toggle("Trusted Person", isOn: $isTrusted)
                    .onChange(of: isTrusted) { _, newValue in
                        Task {
                            await NetworkService.shared.updatePerson(
                                name: person.name,
                                isTrusted: newValue
                            )
                            await onUpdate()
                        }
                    }
            }
        }
        .navigationTitle(person.name)
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview {
    PeoplePageView()
}
