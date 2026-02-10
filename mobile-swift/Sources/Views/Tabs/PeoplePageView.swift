import SwiftUI

// MARK: - People Page

struct PeoplePageView: View {
    enum TrustedFilter: String, CaseIterable {
        case all = "All"
        case trusted = "Trusted"
    }

    var onAccountTap: (() -> Void)? = nil

    @State private var people: [Person] = []
    @State private var filter: TrustedFilter = .all

    @Environment(ScrollState.self) private var scrollState

    private var filteredPeople: [Person] {
        var result = people

        if filter == .trusted {
            result = result.filter { $0.isTrusted }
        }

        return result
    }

    private var trustedCount: Int {
        people.filter(\.isTrusted).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Filter") {
                    Picker("Filter", selection: $filter) {
                        Text("All (\(people.count))").tag(TrustedFilter.all)
                        Text("Trusted (\(trustedCount))").tag(TrustedFilter.trusted)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if filteredPeople.isEmpty {
                        ContentUnavailableView(
                            "No People",
                            systemImage: "person.2.slash",
                            description: Text("Add people to track who suggests movies.")
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
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.update(offset: offset)
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadPeople()
            }
            .task {
                await loadPeople()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let onAccountTap {
                        Button(action: onAccountTap) {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Open account")
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
