import SwiftUI

// MARK: - People Page

struct PeoplePageView: View {
    @State private var repository = MovieRepository.shared

    enum TrustedFilter: String, CaseIterable {
        case all = "All"
        case trusted = "Trusted"
        case quick = "Quick"
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case mostMovies = "Most Movies"
        case trustedFirst = "Trusted First"

        var id: String { rawValue }
    }

    @State private var people: [Person] = []
    @State private var isLoading = false
    @State private var hasLoadedInitialData = false
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var filter: TrustedFilter = .all
    @State private var sortBy: SortOption = .name
    @State private var showFilters = false
    @State private var showAddPerson = false

    private var filteredPeople: [Person] {
        var result = people

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            result = result.filter { person in
                if person.name.localizedCaseInsensitiveContains(trimmedQuery) {
                    return true
                }
                if let emoji = PersonAppearance.normalizedEmoji(person.emoji),
                   emoji.localizedCaseInsensitiveContains(trimmedQuery) {
                    return true
                }
                if person.isTrusted && "trusted".localizedCaseInsensitiveContains(trimmedQuery) {
                    return true
                }
                if person.isQuick && "quick".localizedCaseInsensitiveContains(trimmedQuery) {
                    return true
                }
                return false
            }
        }

        switch filter {
        case .all:
            break
        case .trusted:
            result = result.filter { $0.isTrusted }
        case .quick:
            result = result.filter { $0.isQuick }
        }

        return sortedPeople(result)
    }

    private var trustedCount: Int {
        people.filter(\.isTrusted).count
    }

    private var quickCount: Int {
        people.filter(\.isQuick).count
    }

    var body: some View {
        let visiblePeople = filteredPeople

        NavigationStack {
            List {
                Section {
                    if visiblePeople.isEmpty {
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
                        ForEach(visiblePeople) { person in
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
                                        _ = await repository.updatePerson(
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
                                        _ = await repository.updatePerson(
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
                    Text("\(visiblePeople.count) people")
                } footer: {
                    Text("Swipe right or use the context menu to toggle trust.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search people"
            )
            .refreshable {
                await loadPeople(forceSync: true)
            }
            .task {
                guard !hasLoadedInitialData else { return }
                hasLoadedInitialData = true
                if people.isEmpty {
                    await loadPeople()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAddPerson = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add person")

                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Sort and filter")
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonFullScreenView(
                    onAdded: {
                        showAddPerson = false
                        Task {
                            await loadPeople(forceSync: true)
                        }
                    },
                    onClose: {
                        showAddPerson = false
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFilters) {
                PeopleFilterSortSheet(
                    sortBy: $sortBy,
                    filter: $filter,
                    totalPeopleCount: people.count,
                    trustedCount: trustedCount,
                    quickCount: quickCount
                )
                .presentationDetents([.large])
            }
        }
    }

    private func loadPeople(forceSync: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if forceSync {
            _ = await repository.syncPeople(force: true)
        }
        let result = await repository.getPeople()
        switch result {
        case .success(let loaded):
            people = loaded
        case .failure:
            people = repository.people
        }
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
    let quickCount: Int
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
                        Text("Quick (\(quickCount))").tag(PeoplePageView.TrustedFilter.quick)
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
            PersonAvatarView(
                name: person.name,
                emoji: person.emoji,
                colorHex: person.color,
                isQuick: person.isQuick,
                isTrusted: person.isTrusted
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.headline)

                Text("\(person.movieCount) movie\(person.movieCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if person.isQuick {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(PersonAppearance.color(from: PersonAppearance.quickFallbackColorHex, isQuick: true))
                        .font(.caption)
                }
                if person.isTrusted {
                    Label("Trusted", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
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
    @State private var selectedColorHex: String
    @State private var selectedEmoji: String?
    @State private var recommendedMovies: [Movie] = []
    @State private var showRenameAlert = false
    @State private var editedName = ""
    @State private var renameError: String? = nil
    @Environment(\.dismiss) private var dismiss

    init(person: Person, onUpdate: @escaping () async -> Void) {
        self.person = person
        self.onUpdate = onUpdate
        _isTrusted = State(initialValue: person.isTrusted)
        _selectedColorHex = State(
            initialValue: person.color ?? (
                person.isQuick ? PersonAppearance.quickFallbackColorHex : PersonAppearance.regularFallbackColorHex
            )
        )
        _selectedEmoji = State(initialValue: PersonAppearance.normalizedEmoji(person.emoji))
    }

    var body: some View {
        Form {
            Section("Profile") {
                HStack(spacing: 12) {
                    PersonAvatarView(
                        name: person.name,
                        emoji: selectedEmoji,
                        colorHex: selectedColorHex,
                        isQuick: person.isQuick,
                        isTrusted: isTrusted,
                        size: 46
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(.headline)
                        if let emoji = selectedEmoji {
                            Text("Emoji \(emoji)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LabeledContent("Name") {
                    Text(person.name)
                }
                LabeledContent("Votes") {
                    Text("\(person.movieCount)")
                }
                Button("Rename") {
                    editedName = person.name
                    renameError = nil
                    showRenameAlert = true
                }
            }

            Section("Trust") {
                Toggle("Trusted Person", isOn: $isTrusted)
                    .onChange(of: isTrusted) { _, newValue in
                        Task {
                            _ = await MovieRepository.shared.updatePerson(
                                name: person.name,
                                isTrusted: newValue
                            )
                            await onUpdate()
                        }
                    }
            }

            Section("Appearance") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PersonAppearance.colorHexOptions, id: \.self) { option in
                            Button {
                                Task { await setColor(option) }
                            } label: {
                                Circle()
                                    .fill(PersonAppearance.color(from: option, isQuick: person.isQuick))
                                    .frame(
                                        width: PersonAppearance.minimumControlSize,
                                        height: PersonAppearance.minimumControlSize
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedColorHex == option ? Color.accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                            .padding(-4)
                                    )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                            .accessibilityLabel("Color \(PersonAppearance.colorName(for: option))")
                            .accessibilityAddTraits(selectedColorHex == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PersonAppearance.emojiOptions, id: \.self) { option in
                            Button {
                                Task { await setEmoji(option) }
                            } label: {
                                Text(option)
                                    .font(.title3)
                                    .frame(
                                        width: PersonAppearance.minimumControlSize,
                                        height: PersonAppearance.minimumControlSize
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedEmoji == option ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Emoji \(option)")
                            .accessibilityAddTraits(selectedEmoji == option ? .isSelected : [])
                        }

                        Button {
                            Task { await clearEmoji() }
                        } label: {
                            Text("None")
                                .font(.caption.weight(.semibold))
                                .frame(minWidth: PersonAppearance.minimumControlSize)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedEmoji == nil ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("No emoji")
                        .accessibilityAddTraits(selectedEmoji == nil ? .isSelected : [])
                    }
                    .padding(.vertical, 4)
                }
            }

            if !recommendedMovies.isEmpty {
                Section("Movies Voted (\(recommendedMovies.count))") {
                    ForEach(recommendedMovies) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                CachedAsyncImage(url: movie.posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(.secondary.opacity(0.2))
                                        Image(systemName: "film")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 40, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(movie.title)
                                        .font(.headline)
                                    if let year = movie.releaseDate?.prefix(4) {
                                        Text(String(year))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let imdbRating = movie.imdbRating {
                                        Text("IMDb \(String(format: "%.1f", imdbRating))")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                    if let rottenTomatoes = movie.rottenTomatoesRating {
                                        if rottenTomatoes >= 75 {
                                            Label("\(rottenTomatoes)%", systemImage: "burst.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                        } else if rottenTomatoes >= 60 {
                                            Text("🍅 \(rottenTomatoes)%")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                        } else {
                                            Label("\(rottenTomatoes)%", systemImage: "burst.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    if let metacritic = movie.metacriticScore {
                                        Label("\(metacritic)", systemImage: "gauge.medium")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadRecommendedMovies()
        }
        .alert("Rename Person", isPresented: $showRenameAlert) {
            TextField("Name", text: $editedName)
            Button("Save") {
                Task { await performRename() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let error = renameError {
                Text(error)
            } else {
                Text("Enter a new name for \(person.name)")
            }
        }
    }

    private func performRename() async {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != person.name else { return }
        let result = await MovieRepository.shared.renamePerson(name: person.name, newName: trimmed)
        switch result {
        case .success:
            await onUpdate()
            dismiss()
        case .failure(let error):
            renameError = error.localizedDescription
            showRenameAlert = true
        }
    }

    private func setColor(_ colorHex: String) async {
        let previous = selectedColorHex
        selectedColorHex = colorHex
        await NetworkService.shared.updatePersonAppearance(name: person.name, color: colorHex)
        if NetworkService.shared.lastError == nil {
            await onUpdate()
        } else {
            selectedColorHex = previous
        }
    }

    private func setEmoji(_ emoji: String) async {
        let previous = selectedEmoji
        selectedEmoji = emoji
        await NetworkService.shared.updatePersonAppearance(name: person.name, emoji: emoji)
        if NetworkService.shared.lastError == nil {
            await onUpdate()
        } else {
            selectedEmoji = previous
        }
    }

    private func clearEmoji() async {
        let previous = selectedEmoji
        selectedEmoji = nil
        await NetworkService.shared.updatePersonAppearance(name: person.name, clearEmoji: true)
        if NetworkService.shared.lastError == nil {
            await onUpdate()
        } else {
            selectedEmoji = previous
        }
    }

    private func loadRecommendedMovies() async {
        let result = await MovieRepository.shared.getPersonMovies(personName: person.name)
        switch result {
        case .success(let movies):
            recommendedMovies = movies
        case .failure:
            recommendedMovies = []
        }
    }
}


#Preview {
    PeoplePageView()
}
