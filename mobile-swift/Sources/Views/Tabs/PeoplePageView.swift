import SwiftUI

// MARK: - People Page

struct PeoplePageView: View {
    @State private var repository = MovieRepository.shared

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

    @State private var people: [Person] = []
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
                    Text("\(filteredPeople.count) people")
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
                await loadPeople()
            }
            .onAppear {
                Task {
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
                    trustedCount: trustedCount
                )
                .presentationDetents([.large])
            }
        }
    }

    private func loadPeople(forceSync: Bool = false) async {
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
    @State private var recommendedMovies: [Movie] = []

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
                LabeledContent("Votes") {
                    Text("\(person.movieCount)")
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

// MARK: - Movie Detail View (for navigation from person detail)

private struct MovieDetailView: View {
    @State private var currentMovie: Movie
    @State private var isRefreshingMetadata = false
    @State private var feedbackMessage = ""
    @State private var showFeedbackAlert = false

    init(movie: Movie) {
        _currentMovie = State(initialValue: movie)
    }

    private var likedRecommendations: [Recommendation] {
        currentMovie.recommendations.filter { !isDownvote($0) }
    }

    private var dislikedRecommendations: [Recommendation] {
        currentMovie.recommendations.filter { isDownvote($0) }
    }

    private var relatedMovies: [Movie] {
        let cached = MovieRepository.shared.movies
        return cached.isEmpty ? [currentMovie] : cached
    }

    private var uniqueGenres: [String] {
        normalizedUnique(currentMovie.genres)
    }

    private var uniqueActors: [String] {
        normalizedUnique(currentMovie.actors)
    }

    private var uniqueDirectors: [String] {
        normalizedUnique(splitPeopleList(currentMovie.director))
    }

    var body: some View {
        Form {
            Section {
                CachedAsyncImage(url: currentMovie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.secondary.opacity(0.15))
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Section("Details") {
                LabeledContent("Title") {
                    Text(currentMovie.title)
                }
                if let year = currentMovie.releaseDate?.prefix(4) {
                    LabeledContent("Year") {
                        Text(String(year))
                    }
                }
                if !uniqueGenres.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Genres")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(uniqueGenres, id: \.self) { genre in
                            NavigationLink {
                                MovieGenreExplorerView(
                                    genre: genre,
                                    movies: relatedMovies,
                                    sourceImdbId: currentMovie.imdbId
                                )
                            } label: {
                                Text(genre)
                            }
                        }
                    }
                }

                if !uniqueDirectors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Director")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(uniqueDirectors, id: \.self) { director in
                            NavigationLink {
                                MovieCreditExplorerView(
                                    personName: director,
                                    movies: relatedMovies,
                                    sourceImdbId: currentMovie.imdbId,
                                    preferredSearchType: .director
                                )
                            } label: {
                                Text(director)
                            }
                        }
                    }
                }

                if !uniqueActors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Actors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(uniqueActors, id: \.self) { actor in
                            NavigationLink {
                                MovieCreditExplorerView(
                                    personName: actor,
                                    movies: relatedMovies,
                                    sourceImdbId: currentMovie.imdbId,
                                    preferredSearchType: .actor
                                )
                            } label: {
                                Text(actor)
                            }
                        }
                    }
                }
            }

            if let overview = currentMovie.overview, !overview.isEmpty {
                Section("Overview") {
                    Text(overview)
                }
            }

            if !likedRecommendations.isEmpty {
                Section("Upvoted By") {
                    ForEach(Array(likedRecommendations.enumerated()), id: \.offset) { _, rec in
                        Text(rec.recommender)
                    }
                }
            }

            if !dislikedRecommendations.isEmpty {
                Section("Downvoted By") {
                    ForEach(Array(dislikedRecommendations.enumerated()), id: \.offset) { _, rec in
                        Text(rec.recommender)
                    }
                }
            }
        }
        .navigationTitle("Movie")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await refreshMetadataFromBackend()
                    }
                } label: {
                    if isRefreshingMetadata {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshingMetadata)
                .accessibilityLabel("Refresh movie data")
            }
        }
        .alert("Movie Details", isPresented: $showFeedbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(feedbackMessage)
        }
        .task {
            _ = await MovieRepository.shared.getMovies(status: nil)
            if let refreshed = MovieRepository.shared.movies.first(where: { $0.imdbId == currentMovie.imdbId }) {
                currentMovie = refreshed
            }
        }
    }

    private func refreshMetadataFromBackend() async {
        guard !isRefreshingMetadata else { return }
        isRefreshingMetadata = true
        defer { isRefreshingMetadata = false }

        let result = await MovieRepository.shared.refreshMovieMetadata(imdbId: currentMovie.imdbId)
        switch result {
        case .success(let movie):
            currentMovie = movie
        case .failure(let error):
            feedbackMessage = error.localizedDescription
            showFeedbackAlert = true
        }
    }

    private func isDownvote(_ recommendation: Recommendation) -> Bool {
        recommendation.voteType.lowercased() == "downvote"
    }

    private func normalizedUnique(_ values: [String]) -> [String] {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private func splitPeopleList(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    PeoplePageView()
}
