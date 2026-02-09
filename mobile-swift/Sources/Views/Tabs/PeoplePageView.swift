import SwiftUI

// MARK: - People Page
// Recommender management with stats, trust badges, swipe actions,
// search, and detail view.

struct PeoplePageView: View {
    var onAccountTap: (() -> Void)? = nil
    @State private var people: [Person] = []
    @State private var filterTrusted: Bool?
    @Environment(ScrollState.self) private var scrollState
    @Environment(SearchState.self) private var searchState

    private var filteredPeople: [Person] {
        var result = people
        if !searchState.searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchState.searchText) }
        }
        if let trusted = filterTrusted {
            result = result.filter { $0.isTrusted == trusted }
        }
        return result
    }

    private var trustedCount: Int {
        people.filter(\.isTrusted).count
    }

    var body: some View {
        NavigationStack {
            List {
                // Filter chips
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All (\(people.count))", isSelected: filterTrusted == nil) {
                                withAnimation { filterTrusted = nil }
                            }
                            FilterChip(title: "Trusted (\(trustedCount))", isSelected: filterTrusted == true) {
                                withAnimation { filterTrusted = filterTrusted == true ? nil : true }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                // People list
                Section("\(filteredPeople.count) people") {
                    if filteredPeople.isEmpty {
                        ContentUnavailableView(
                            "No People",
                            systemImage: "person.2.slash",
                            description: Text("Add recommenders to track who suggests movies.")
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
                                        person.isTrusted ? "Untrust" : "Trust",
                                        systemImage: person.isTrusted ? "star.slash.fill" : "star.fill"
                                    )
                                }
                                .tint(person.isTrusted ? .orange : .green)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 80)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.update(offset: offset)
                }
            }
            .background { PageBackground() }
            .navigationTitle("People")
            .refreshable {
                await loadPeople()
            }
            .task {
                await loadPeople()
            }
            .toolbar {
                if let onAccountTap {
                    ToolbarItem(placement: .topBarTrailing) {
                        AccountToolbarButton(action: onAccountTap)
                    }
                }
            }
        }
    }

    private func loadPeople() async {
        await NetworkService.shared.fetchPeople()
        people = NetworkService.shared.people
    }
}

// MARK: - Person Row

private struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: person.isTrusted ? [.blue, .purple] : [AppTheme.surface, AppTheme.surfaceMuted],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(person.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(person.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    if person.isTrusted {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text("\(person.movieCount) movie\(person.movieCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Person Detail View

private struct PersonDetailView: View {
    let person: Person
    let onUpdate: () async -> Void
    @State private var isTrusted: Bool
    @Environment(\.dismiss) private var dismiss

    init(person: Person, onUpdate: @escaping () async -> Void) {
        self.person = person
        self.onUpdate = onUpdate
        _isTrusted = State(initialValue: person.isTrusted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 14) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isTrusted ? [.blue, .purple, .pink] : [AppTheme.surface, AppTheme.surfaceMuted],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(String(person.name.prefix(1)).uppercased())
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(person.name)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)

                            if isTrusted {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                    Text("Trusted")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.yellow.opacity(0.15), in: .capsule)
                            }
                        }

                        Text("\(person.movieCount) recommendations")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }

                // Stats
                FrostedCard {
                    HStack(spacing: 0) {
                        statCell(value: "\(person.movieCount)", label: "Movies", icon: "film.fill")
                        statCell(value: isTrusted ? "Yes" : "No", label: "Trusted", icon: "star.fill")
                    }
                    .padding(.vertical, 12)
                }

                // Trust toggle
                FrostedCard {
                    Toggle(isOn: $isTrusted) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(isTrusted ? .yellow : AppTheme.textTertiary)
                                .frame(width: 22)
                            Text("Trusted Recommender")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .padding(14)
                    .tint(AppTheme.blue)
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
            .padding(16)
        }
        .background { PageBackground() }
        .navigationTitle(person.name)
        .toolbarTitleDisplayMode(.inline)
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(AppTheme.blue)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PeoplePageView()
}
