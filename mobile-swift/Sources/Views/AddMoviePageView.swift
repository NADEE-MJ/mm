import SwiftUI

enum DiscoverSearchType: String, CaseIterable, Identifiable {
    case title
    case genre
    case actor
    case director

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title:
            return "Title"
        case .genre:
            return "Genre"
        case .actor:
            return "Actor"
        case .director:
            return "Director"
        }
    }

    var tokenKey: String { rawValue }

    func prefilledTokenQuery(_ value: String) -> String {
        "\(tokenKey):\(DiscoverParsedFilters.quotedTokenValue(value)) in:discover"
    }
}

private enum DiscoverSearchScope: String, CaseIterable {
    case discover
    case library
    case all

    var label: String {
        switch self {
        case .discover:
            return "Discover"
        case .library:
            return "Library"
        case .all:
            return "All"
        }
    }

    var includesDiscover: Bool {
        self == .discover || self == .all
    }

    var includesLibrary: Bool {
        self == .library || self == .all
    }
}

private enum DiscoverFilterKind: String {
    case text
    case title
    case genre
    case actor
    case director
    case year
    case rating
    case scope

    var label: String {
        switch self {
        case .text:
            return "text"
        case .title:
            return "title"
        case .genre:
            return "genre"
        case .actor:
            return "actor"
        case .director:
            return "director"
        case .year:
            return "year"
        case .rating:
            return "rating"
        case .scope:
            return "in"
        }
    }
}

private struct DiscoverFilterChip: Identifiable, Hashable {
    let kind: DiscoverFilterKind
    let value: String

    var id: String {
        "\(kind.rawValue)|\(value.lowercased())"
    }

    var displayText: String {
        "\(kind.label): \(value)"
    }
}

private struct DiscoverParsedFilters: Equatable {
    var freeText: String = ""
    var titleValues: [String] = []
    var genres: [String] = []
    var actors: [String] = []
    var directors: [String] = []
    var years: [Int] = []
    var minimumRating: Double?
    var scope: DiscoverSearchScope = .discover

    var hasSearchCriteria: Bool {
        !freeText.isEmpty ||
            !titleValues.isEmpty ||
            !genres.isEmpty ||
            !actors.isEmpty ||
            !directors.isEmpty ||
            !years.isEmpty ||
            minimumRating != nil
    }

    var discoverTitleQuery: String? {
        let combined = (titleValues + [freeText])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    var offlineQueueTitle: String? {
        if let firstTitle = titleValues.first {
            return firstTitle
        }
        return freeText.isEmpty ? nil : freeText
    }

    var chips: [DiscoverFilterChip] {
        var values: [DiscoverFilterChip] = []
        if !freeText.isEmpty {
            values.append(DiscoverFilterChip(kind: .text, value: freeText))
        }
        for title in titleValues {
            values.append(DiscoverFilterChip(kind: .title, value: title))
        }
        for genre in genres {
            values.append(DiscoverFilterChip(kind: .genre, value: genre))
        }
        for actor in actors {
            values.append(DiscoverFilterChip(kind: .actor, value: actor))
        }
        for director in directors {
            values.append(DiscoverFilterChip(kind: .director, value: director))
        }
        for year in years {
            values.append(DiscoverFilterChip(kind: .year, value: String(year)))
        }
        if let minimumRating {
            values.append(DiscoverFilterChip(kind: .rating, value: String(format: "%.1f", minimumRating)))
        }
        values.append(DiscoverFilterChip(kind: .scope, value: scope.label))
        return values
    }

    mutating func removeChip(_ chip: DiscoverFilterChip) {
        switch chip.kind {
        case .text:
            freeText = ""
        case .title:
            titleValues.removeAll { $0.caseInsensitiveCompare(chip.value) == .orderedSame }
        case .genre:
            genres.removeAll { $0.caseInsensitiveCompare(chip.value) == .orderedSame }
        case .actor:
            actors.removeAll { $0.caseInsensitiveCompare(chip.value) == .orderedSame }
        case .director:
            directors.removeAll { $0.caseInsensitiveCompare(chip.value) == .orderedSame }
        case .year:
            if let year = Int(chip.value) {
                years.removeAll { $0 == year }
            }
        case .rating:
            minimumRating = nil
        case .scope:
            scope = .discover
        }
    }

    mutating func setScope(_ newScope: DiscoverSearchScope) {
        scope = newScope
    }

    mutating func addValue(_ value: String, for kind: DiscoverFilterKind) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch kind {
        case .title:
            titleValues.append(trimmed)
        case .genre:
            genres.append(trimmed)
        case .actor:
            actors.append(trimmed)
        case .director:
            directors.append(trimmed)
        case .year:
            if let year = Int(trimmed) {
                years.append(year)
                years = Array(Set(years)).sorted(by: >)
            }
        case .rating:
            if let rating = Double(trimmed) {
                minimumRating = rating
            }
        case .text:
            freeText = trimmed
        case .scope:
            if let parsedScope = DiscoverSearchScope(rawValue: trimmed.lowercased()) {
                scope = parsedScope
            }
        }
    }

    func toQueryString() -> String {
        var parts: [String] = []
        if !freeText.isEmpty {
            parts.append(Self.quotedTokenValue(freeText))
        }
        parts.append(contentsOf: titleValues.map { "title:\(Self.quotedTokenValue($0))" })
        parts.append(contentsOf: genres.map { "genre:\(Self.quotedTokenValue($0))" })
        parts.append(contentsOf: actors.map { "actor:\(Self.quotedTokenValue($0))" })
        parts.append(contentsOf: directors.map { "director:\(Self.quotedTokenValue($0))" })
        parts.append(contentsOf: years.map { "year:\($0)" })
        if let minimumRating {
            parts.append("rating:\(String(format: "%.1f", minimumRating))")
        }
        if scope != .discover {
            parts.append("in:\(scope.rawValue)")
        }
        return parts.joined(separator: " ")
    }

    static func parse(_ raw: String) -> DiscoverParsedFilters {
        var parsed = DiscoverParsedFilters()
        var freeTextParts: [String] = []

        for token in tokenize(raw) {
            guard let separatorIndex = token.firstIndex(of: ":") else {
                freeTextParts.append(token)
                continue
            }

            let key = String(token[..<separatorIndex]).lowercased()
            let valueStartIndex = token.index(after: separatorIndex)
            guard valueStartIndex < token.endIndex else {
                freeTextParts.append(token)
                continue
            }

            let rawValue = String(token[valueStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty else { continue }

            switch key {
            case "title", "t":
                parsed.titleValues.append(rawValue)
            case "genre", "g":
                parsed.genres.append(rawValue)
            case "actor", "a":
                parsed.actors.append(rawValue)
            case "director", "d":
                parsed.directors.append(rawValue)
            case "year", "y":
                if let year = Int(rawValue) {
                    parsed.years.append(year)
                }
            case "rating", "r":
                if let rating = Double(rawValue) {
                    parsed.minimumRating = rating
                }
            case "in", "scope":
                if let scope = DiscoverSearchScope(rawValue: rawValue.lowercased()) {
                    parsed.scope = scope
                }
            default:
                freeTextParts.append(token)
            }
        }

        parsed.freeText = freeTextParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        parsed.years = Array(Set(parsed.years)).sorted(by: >)
        return parsed
    }

    static func quotedTokenValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\"\"" }
        if trimmed.contains(where: \.isWhitespace) {
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "")
            return "\"\(escaped)\""
        }
        return trimmed
    }

    private static func tokenize(_ raw: String) -> [String] {
        var output: [String] = []
        var current = ""
        var activeQuote: Character?

        for character in raw {
            if character == "\"" || character == "'" {
                if activeQuote == nil {
                    activeQuote = character
                    continue
                }
                if activeQuote == character {
                    activeQuote = nil
                    continue
                }
            }

            if character.isWhitespace && activeQuote == nil {
                if !current.isEmpty {
                    output.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            output.append(current)
        }

        return output
    }
}

private enum DiscoverRailCategory: CaseIterable, Identifiable, Hashable {
    case popularNow
    case inTheaters
    case trendingNow
    case comingSoon
    case topRatedNow

    var id: String {
        switch self {
        case .comingSoon:
            return "coming_soon"
        case .inTheaters:
            return "in_theaters"
        case .popularNow:
            return "popular_now"
        case .topRatedNow:
            return "top_rated_now"
        case .trendingNow:
            return "trending_now"
        }
    }

    var title: String {
        switch self {
        case .comingSoon:
            return "Coming Soon"
        case .inTheaters:
            return "In Theaters"
        case .popularNow:
            return "Popular Right Now"
        case .topRatedNow:
            return "Top Rated"
        case .trendingNow:
            return "Trending Right Now"
        }
    }
}

@MainActor
@Observable
final class DiscoverNavigationState {
    static let shared = DiscoverNavigationState()

    private(set) var requestId: Int = 0
    private(set) var searchType: DiscoverSearchType = .title
    private(set) var query: String = ""

    private init() {}

    func open(searchType: DiscoverSearchType, query: String) {
        self.searchType = searchType
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        requestId &+= 1
    }
}

// MARK: - Add Movie Page

struct AddMoviePageView: View {
    var onClose: (() -> Void)? = nil

    @State private var repository = MovieRepository.shared
    @State private var searchResults: [TMDBMovie] = []
    @State private var librarySearchResults: [Movie] = []
    @State private var isLoadingResults = false
    @State private var selectedMovie: TMDBMovie?
    @State private var selectedRecommenders: Set<String> = []
    @State private var people: [Person] = []
    @State private var searchText = ""
    @State private var isSearchPresented = true
    @State private var showSearchFiltersSheet = false
    @State private var pendingFilterKind: DiscoverFilterKind?
    @State private var pendingFilterValue: String = ""
    @State private var existingMovieTmdbIds: Set<Int> = []
    @State private var showOfflineAddSheet = false
    @State private var selectedPendingMovie: DatabaseManager.PendingMovie?
    @State private var pendingOfflineMovies: [DatabaseManager.PendingMovie] = []
    @State private var feedbackMessage = ""
    @State private var showFeedbackAlert = false
    @State private var discoverNavigation = DiscoverNavigationState.shared
    @State private var handledDiscoverRequestId = 0
    @State private var curatedMoviesByCategory: [DiscoverRailCategory: [TMDBMovie]] = [:]
    @State private var isLoadingCuratedMovies = false
    @State private var didAttemptCuratedLoad = false

    init(
        onClose: (() -> Void)? = nil,
        initialSearchType: DiscoverSearchType = .title,
        initialQuery: String = ""
    ) {
        self.onClose = onClose
        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            _searchText = State(initialValue: "")
        } else if trimmed.contains(":") {
            _searchText = State(initialValue: trimmed)
        } else {
            _searchText = State(initialValue: initialSearchType.prefilledTokenQuery(trimmed))
        }
    }

    private var trimmedSearchTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedFilters: DiscoverParsedFilters {
        DiscoverParsedFilters.parse(searchText)
    }

    private var isSheetPresentation: Bool {
        onClose != nil
    }

    private var hasSearchQuery: Bool {
        parsedFilters.hasSearchCriteria
    }

    private var hasAnyCuratedMovies: Bool {
        DiscoverRailCategory.allCases.contains { !(curatedMoviesByCategory[$0] ?? []).isEmpty }
    }

    private var visibleFilterChips: [DiscoverFilterChip] {
        parsedFilters.chips.filter { chip in
            !(chip.kind == .scope && parsedFilters.scope == .discover)
        }
    }

    private var activeFilterCount: Int {
        visibleFilterChips.count
    }

    var body: some View {
        NavigationStack {
            List {
                if !pendingOfflineMovies.isEmpty {
                    Section {
                        ForEach(pendingOfflineMovies) { pendingMovie in
                            Button {
                                selectedPendingMovie = pendingMovie
                            } label: {
                                PendingOfflineMovieRow(pendingMovie: pendingMovie)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    repository.deletePendingMovie(id: pendingMovie.id)
                                    pendingOfflineMovies = repository.fetchPendingMovies()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Pending Offline Movies (\(pendingOfflineMovies.count))")
                    } footer: {
                        Text("Choose the exact movie match after reconnecting.")
                    }
                }

                if !hasSearchQuery {
                    if isLoadingCuratedMovies && !didAttemptCuratedLoad {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }

                    ForEach(DiscoverRailCategory.allCases) { category in
                        let movies = curatedMoviesByCategory[category] ?? []
                        if !movies.isEmpty {
                            CuratedCategoryCard(
                                title: category.title,
                                movies: movies,
                                existingMovieTmdbIds: existingMovieTmdbIds
                            ) { selected in
                                selectedMovie = selected
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }

                    if didAttemptCuratedLoad && !isLoadingCuratedMovies && !hasAnyCuratedMovies {
                        Section {
                            ContentUnavailableView(
                                "No Live Discover Results",
                                systemImage: "wifi.slash",
                                description: Text("Connect to the internet to load Coming Soon, In Theaters, Popular, Top Rated, and Trending movies.")
                            )
                        }
                    }
                }

                if hasSearchQuery {
                    if isLoadingResults {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } header: {
                            Text("Searching")
                        }
                    } else if searchResults.isEmpty && librarySearchResults.isEmpty {
                        Section {
                            ContentUnavailableView.search

                            if let offlineTitle = parsedFilters.offlineQueueTitle {
                                Button {
                                    showOfflineAddSheet = true
                                } label: {
                                    Label("Add \"\(offlineTitle)\" Offline", systemImage: "tray.and.arrow.down.fill")
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } footer: {
                            Text("Try fewer filters, or broaden the query.")
                        }
                    } else {
                        if !searchResults.isEmpty {
                            Section("Discover Results (\(searchResults.count))") {
                                ForEach(searchResults) { movie in
                                    let isAlreadyAdded = existingMovieTmdbIds.contains(movie.id)
                                    Button {
                                        if !isAlreadyAdded {
                                            selectedMovie = movie
                                        }
                                    } label: {
                                        SearchResultRow(movie: movie, isAlreadyAdded: isAlreadyAdded)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isAlreadyAdded)
                                }
                            }
                        }

                        if !librarySearchResults.isEmpty {
                            Section("Library Results (\(librarySearchResults.count))") {
                                ForEach(librarySearchResults) { movie in
                                    LibrarySearchResultRow(movie: movie)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: "Search titles or use filters"
            )
            .toolbar {
                if isSheetPresentation {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onClose?()
                        }
                        label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearchFiltersSheet = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule(style: .continuous).fill(AppTheme.blue))
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .accessibilityLabel("Search filters")
                }
            }
            .onAppear {
                isSearchPresented = true
                applyDiscoverNavigationRequest()
            }
            .onChange(of: discoverNavigation.requestId) { _, _ in
                applyDiscoverNavigationRequest()
            }
            .task(id: searchText) {
                let filters = parsedFilters
                guard filters.hasSearchCriteria else {
                    searchResults = []
                    librarySearchResults = []
                    isLoadingResults = false
                    return
                }

                isLoadingResults = true
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                if filters.scope.includesDiscover {
                    searchResults = await searchDiscoverMovies(filters)
                } else {
                    searchResults = []
                }

                if filters.scope.includesLibrary {
                    librarySearchResults = searchLibraryMovies(filters, from: repository.movies)
                } else {
                    librarySearchResults = []
                }

                isLoadingResults = false
            }
            .task {
                let peopleResult = await repository.getPeople()
                switch peopleResult {
                case .success(let loaded):
                    people = loaded
                case .failure:
                    people = repository.people
                }

                _ = await repository.getMovies(status: nil)
                existingMovieTmdbIds = Set(repository.movies.compactMap { $0.tmdbId })
                pendingOfflineMovies = repository.fetchPendingMovies()
                await loadCuratedMovies()

                if parsedFilters.scope.includesLibrary, parsedFilters.hasSearchCriteria {
                    librarySearchResults = searchLibraryMovies(parsedFilters, from: repository.movies)
                }
            }
            .sheet(item: $selectedMovie, onDismiss: {
                selectedRecommenders = []
            }) { movie in
                AddMovieSheet(
                    movie: movie,
                    selectedRecommenders: $selectedRecommenders,
                    people: people,
                    onAdd: {
                        Task {
                            let result = await repository.addMovieBulk(
                                tmdbId: movie.id,
                                recommenders: Array(selectedRecommenders)
                            )

                            switch result {
                            case .success:
                                feedbackMessage = "Movie added successfully."
                                _ = await repository.syncPeople(force: true)
                                let peopleResult = await repository.getPeople()
                                switch peopleResult {
                                case .success(let loaded):
                                    people = loaded
                                case .failure:
                                    people = repository.people
                                }
                            case .failure(.queued(let message)):
                                feedbackMessage = message
                            case .failure(let error):
                                feedbackMessage = error.localizedDescription
                            }

                            showFeedbackAlert = true
                            selectedMovie = nil
                            selectedRecommenders = []
                            _ = await repository.getMovies(status: nil)
                            existingMovieTmdbIds = Set(repository.movies.compactMap { $0.tmdbId })
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $selectedPendingMovie) { pendingMovie in
                ResolvePendingMovieSheet(pendingMovie: pendingMovie) { selectedMatch in
                    Task {
                        let result = await repository.resolvePendingMovie(
                            pendingMovieId: pendingMovie.id,
                            tmdbId: selectedMatch.id
                        )

                        switch result {
                        case .success:
                            feedbackMessage = "Added \"\(selectedMatch.title)\"."
                        case .failure(.queued(let message)):
                            feedbackMessage = message
                        case .failure(let error):
                            feedbackMessage = error.localizedDescription
                        }

                        showFeedbackAlert = true
                        pendingOfflineMovies = repository.fetchPendingMovies()
                        _ = await repository.getMovies(status: nil)
                        existingMovieTmdbIds = Set(repository.movies.compactMap { $0.tmdbId })
                    }
                } onRemovePending: {
                    repository.deletePendingMovie(id: pendingMovie.id)
                    pendingOfflineMovies = repository.fetchPendingMovies()
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showOfflineAddSheet) {
                OfflineAddMovieSheet(
                    title: parsedFilters.offlineQueueTitle ?? trimmedSearchTitle,
                    people: people
                ) { recommenders in
                    Task {
                        for recommender in recommenders {
                            _ = await repository.queueMovieByTitle(
                                title: parsedFilters.offlineQueueTitle ?? trimmedSearchTitle,
                                recommender: recommender
                            )
                        }
                        feedbackMessage = "Saved offline. Pick the exact movie match after reconnecting."
                        showFeedbackAlert = true
                        pendingOfflineMovies = repository.fetchPendingMovies()
                        showOfflineAddSheet = false
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSearchFiltersSheet) {
                NavigationStack {
                    Form {
                        Section("Source") {
                            Picker(
                                "Source",
                                selection: Binding(
                                    get: { parsedFilters.scope },
                                    set: { updateScope($0) }
                                )
                            ) {
                                ForEach(DiscoverSearchScope.allCases, id: \.rawValue) { scope in
                                    Text(scope.label).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Section("Quick Add") {
                            DiscoverFilterTemplatesRow(
                                onInsertToken: { kind in
                                    insertTemplateToken(kind)
                                }
                            )
                        }

                        if !visibleFilterChips.isEmpty {
                            Section("Active Filters") {
                                DiscoverActiveFiltersRow(
                                    chips: visibleFilterChips,
                                    onRemove: { chip in
                                        removeFilterChip(chip)
                                    },
                                    onClear: {
                                        searchText = ""
                                    }
                                )
                            }
                        }

                        Section("Tips") {
                            Text("Use tokens like genre:\"crime\" actor:\"Tom Hanks\" director:\"Greta Gerwig\" year:2023 rating:7.5 in:discover")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Search Filters")
                    .toolbarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSearchFiltersSheet = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showSearchFiltersSheet = false
                            }
                            .bold()
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .alert(
                "Add Filter",
                isPresented: Binding(
                    get: { pendingFilterKind != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingFilterKind = nil
                            pendingFilterValue = ""
                        }
                    }
                )
            ) {
                TextField(filterValuePlaceholder, text: $pendingFilterValue)
                Button("Cancel", role: .cancel) {
                    pendingFilterKind = nil
                    pendingFilterValue = ""
                }
                Button("Add") {
                    applyPendingFilterInput()
                }
            } message: {
                if let pendingFilterKind {
                    Text("Enter a value for \(pendingFilterKind.label).")
                }
            }
            .alert("Add Movie", isPresented: $showFeedbackAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackMessage)
            }
        }
    }

    private func applyDiscoverNavigationRequest() {
        guard discoverNavigation.requestId > handledDiscoverRequestId else { return }
        handledDiscoverRequestId = discoverNavigation.requestId
        let incoming = discoverNavigation.query
        if incoming.contains(":") {
            searchText = incoming
        } else {
            searchText = discoverNavigation.searchType.prefilledTokenQuery(incoming)
        }
        isSearchPresented = true
    }

    private func updateScope(_ scope: DiscoverSearchScope) {
        var filters = parsedFilters
        filters.setScope(scope)
        searchText = filters.toQueryString()
    }

    private var filterValuePlaceholder: String {
        guard let pendingFilterKind else { return "Value" }
        switch pendingFilterKind {
        case .year:
            return "e.g. 2024"
        case .rating:
            return "e.g. 7.5"
        default:
            return "Enter \(pendingFilterKind.label)"
        }
    }

    private func insertTemplateToken(_ kind: DiscoverFilterKind) {
        pendingFilterKind = kind
        pendingFilterValue = ""
    }

    private func applyPendingFilterInput() {
        guard let selectedFilterKind = pendingFilterKind else { return }
        var filters = parsedFilters
        filters.addValue(pendingFilterValue, for: selectedFilterKind)
        searchText = filters.toQueryString()
        pendingFilterKind = nil
        pendingFilterValue = ""
        isSearchPresented = true
    }

    private func removeFilterChip(_ chip: DiscoverFilterChip) {
        var filters = parsedFilters
        filters.removeChip(chip)
        searchText = filters.toQueryString()
    }

    private func searchDiscoverMovies(_ filters: DiscoverParsedFilters) async -> [TMDBMovie] {
        var buckets: [[TMDBMovie]] = []

        if let titleQuery = filters.discoverTitleQuery {
            buckets.append(await NetworkService.shared.searchMovies(query: titleQuery))
        }

        if !filters.genres.isEmpty {
            var merged: [Int: TMDBMovie] = [:]
            for genre in filters.genres {
                let movies = await NetworkService.shared.discoverMoviesByGenre(query: genre)
                for movie in movies {
                    merged[movie.id] = movie
                }
            }
            buckets.append(Array(merged.values))
        }

        if !filters.actors.isEmpty {
            var merged: [Int: TMDBMovie] = [:]
            for actor in filters.actors {
                let movies = await NetworkService.shared.discoverMoviesByPerson(query: actor, role: "actor")
                for movie in movies {
                    merged[movie.id] = movie
                }
            }
            buckets.append(Array(merged.values))
        }

        if !filters.directors.isEmpty {
            var merged: [Int: TMDBMovie] = [:]
            for director in filters.directors {
                let movies = await NetworkService.shared.discoverMoviesByPerson(query: director, role: "director")
                for movie in movies {
                    merged[movie.id] = movie
                }
            }
            buckets.append(Array(merged.values))
        }

        guard var results = buckets.first else {
            return []
        }

        for bucket in buckets.dropFirst() {
            let ids = Set(bucket.map(\.id))
            results = results.filter { ids.contains($0.id) }
        }

        if !filters.years.isEmpty {
            let yearSet = Set(filters.years)
            results = results.filter { movie in
                guard let yearPrefix = movie.releaseDate?.prefix(4), let year = Int(yearPrefix) else {
                    return false
                }
                return yearSet.contains(year)
            }
        }

        if let minimumRating = filters.minimumRating {
            results = results.filter { ($0.voteAverage ?? 0) >= minimumRating }
        }

        let searchTerms = filters.freeText.lowercased().split(separator: " ").map(String.init)
        if !searchTerms.isEmpty {
            results = results.filter { movie in
                let haystack = "\(movie.title) \(movie.overview ?? "")".lowercased()
                return searchTerms.allSatisfy { haystack.contains($0) }
            }
        }

        var deduped: [Int: TMDBMovie] = [:]
        for movie in results {
            deduped[movie.id] = movie
        }

        return deduped.values.sorted { lhs, rhs in
            let left = lhs.voteAverage ?? 0
            let right = rhs.voteAverage ?? 0
            if left != right {
                return left > right
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func searchLibraryMovies(_ filters: DiscoverParsedFilters, from movies: [Movie]) -> [Movie] {
        var results = movies

        let combinedTitle = (filters.titleValues + [filters.freeText])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !combinedTitle.isEmpty {
            let terms = combinedTitle.split(separator: " ").map(String.init)
            results = results.filter { movie in
                let haystack = "\(movie.title) \(movie.overview ?? "")".lowercased()
                return terms.allSatisfy { haystack.contains($0) }
            }
        }

        if !filters.genres.isEmpty {
            results = results.filter { movie in
                movie.genres.contains { movieGenre in
                    filters.genres.contains { $0.caseInsensitiveCompare(movieGenre) == .orderedSame }
                }
            }
        }

        if !filters.actors.isEmpty {
            results = results.filter { movie in
                movie.actors.contains { actor in
                    filters.actors.contains { $0.caseInsensitiveCompare(actor) == .orderedSame }
                }
            }
        }

        if !filters.directors.isEmpty {
            results = results.filter { movie in
                let directorValues = splitPeopleList(movie.director)
                return directorValues.contains { director in
                    filters.directors.contains { $0.caseInsensitiveCompare(director) == .orderedSame }
                }
            }
        }

        if !filters.years.isEmpty {
            let years = Set(filters.years)
            results = results.filter { movie in
                guard let releaseDate = movie.releaseDate, let year = Int(releaseDate.prefix(4)) else {
                    return false
                }
                return years.contains(year)
            }
        }

        if let minimumRating = filters.minimumRating {
            results = results.filter { movie in
                let ratingCandidates = [movie.imdbRating, movie.voteAverage].compactMap { $0 }
                guard let bestRating = ratingCandidates.max() else { return false }
                return bestRating >= minimumRating
            }
        }

        return results.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func splitPeopleList(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func loadCuratedMovies() async {
        isLoadingCuratedMovies = true
        defer {
            isLoadingCuratedMovies = false
            didAttemptCuratedLoad = true
        }

        async let comingSoon = NetworkService.shared.discoverComingSoonMovies()
        async let inTheaters = NetworkService.shared.discoverNowPlayingMovies()
        async let popular = NetworkService.shared.discoverPopularMovies()
        async let topRated = NetworkService.shared.discoverTopRatedMovies()
        async let trending = NetworkService.shared.discoverTrendingMovies()

        curatedMoviesByCategory[.comingSoon] = await comingSoon
        curatedMoviesByCategory[.inTheaters] = await inTheaters
        curatedMoviesByCategory[.popularNow] = await popular
        curatedMoviesByCategory[.topRatedNow] = await topRated
        curatedMoviesByCategory[.trendingNow] = await trending
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let movie: TMDBMovie
    let isAlreadyAdded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.secondary.opacity(0.2))
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)

                if let year = movie.releaseDate?.prefix(4) {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let overview = movie.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let rating = movie.voteAverage {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                if isAlreadyAdded {
                    Label("Already Added", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()
            Image(systemName: isAlreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                .foregroundStyle(isAlreadyAdded ? .green : AppTheme.blue)
        }
        .padding(.vertical, 2)
    }
}

private struct LibrarySearchResultRow: View {
    let movie: Movie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.secondary.opacity(0.2))
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let year = movie.releaseDate?.prefix(4) {
                        Text(String(year))
                    }
                    Text(movie.status == "watched" ? "Watched" : "To Watch")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                if let imdb = movie.imdbRating {
                    Label("IMDb \(String(format: "%.1f", imdb))", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()
            Label("In Library", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 2)
    }
}

private struct DiscoverFilterTemplatesRow: View {
    let onInsertToken: (DiscoverFilterKind) -> Void

    private let templates: [DiscoverFilterKind] = [.title, .genre, .actor, .director, .year, .rating]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(templates, id: \.rawValue) { template in
                    Button {
                        onInsertToken(template)
                    } label: {
                        Text("+\(template.label)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(.secondarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct DiscoverActiveFiltersRow: View {
    let chips: [DiscoverFilterChip]
    let onRemove: (DiscoverFilterChip) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        Button {
                            onRemove(chip)
                        } label: {
                            HStack(spacing: 6) {
                                Text(chip.displayText)
                                    .font(.caption)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Clear All Filters", role: .destructive) {
                onClear()
            }
            .font(.caption)
        }
    }
}

private struct CuratedCategoryCard: View {
    let title: String
    let movies: [TMDBMovie]
    let existingMovieTmdbIds: Set<Int>
    let onSelect: (TMDBMovie) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            CuratedMovieRailRow(
                movies: movies,
                existingMovieTmdbIds: existingMovieTmdbIds,
                onSelect: onSelect
            )
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct CuratedMovieRailRow: View {
    let movies: [TMDBMovie]
    let existingMovieTmdbIds: Set<Int>
    let onSelect: (TMDBMovie) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(movies) { movie in
                    let isAlreadyAdded = existingMovieTmdbIds.contains(movie.id)
                    Button {
                        if !isAlreadyAdded {
                            onSelect(movie)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                CachedAsyncImage(url: movie.posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(.secondary.opacity(0.2))
                                        Image(systemName: "film")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 96, height: 144)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                if isAlreadyAdded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                        .padding(6)
                                }
                            }

                            Text(movie.title)
                                .font(.caption)
                                .lineLimit(2)
                                .frame(width: 96, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAlreadyAdded)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }
}

private struct PendingOfflineMovieRow: View {
    let pendingMovie: DatabaseManager.PendingMovie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(pendingMovie.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("Recommended by \(pendingMovie.recommender)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Queued \(pendingMovie.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Choose Match", systemImage: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.blue)
                .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}

private struct ResolvePendingMovieSheet: View {
    let pendingMovie: DatabaseManager.PendingMovie
    let onResolve: (TMDBMovie) -> Void
    let onRemovePending: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var results: [TMDBMovie] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Queued Title") {
                    Text(pendingMovie.title)
                        .font(.headline)
                    Text("Recommended by \(pendingMovie.recommender)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if results.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Matches Found",
                            systemImage: "questionmark.circle",
                            description: Text("Try searching in Add Movie, or remove this pending entry.")
                        )
                    }
                } else {
                    Section("Select the correct movie") {
                        ForEach(results) { movie in
                            Button {
                                onResolve(movie)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    CachedAsyncImage(url: movie.posterURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(.secondary.opacity(0.2))
                                            Image(systemName: "film")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 56, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(movie.title)
                                            .font(.headline)

                                        if let year = movie.releaseDate?.prefix(4) {
                                            Text(String(year))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        if let overview = movie.overview {
                                            Text(overview)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Resolve Offline Movie")
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Remove", role: .destructive) {
                        onRemovePending()
                        dismiss()
                    }
                }
            }
            .task {
                isLoading = true
                results = await NetworkService.shared.searchMovies(query: pendingMovie.title)
                isLoading = false
            }
        }
    }
}

// MARK: - Add Movie Sheet

private struct AddMovieSheet: View {
    let movie: TMDBMovie
    @Binding var selectedRecommenders: Set<String>
    let people: [Person]
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var newPersonName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section("Movie") {
                        HStack(alignment: .top, spacing: 12) {
                            CachedAsyncImage(url: movie.posterURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.secondary.opacity(0.2))
                                    Image(systemName: "film")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 64, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(movie.title)
                                    .font(.headline)

                                if let year = movie.releaseDate?.prefix(4) {
                                    Text(String(year))
                                        .foregroundStyle(.secondary)
                                }

                                if let rating = movie.voteAverage {
                                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                    }

                    Section {
                        HStack {
                            TextField("Add new person", text: $newPersonName)
                                .textInputAutocapitalization(.words)
                            Button {
                                let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                selectedRecommenders.insert(trimmed)
                                newPersonName = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.blue)
                            }
                            .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } header: {
                        Text("Add New Person")
                    } footer: {
                        Text("Type a name and tap + to add")
                    }

                    Section("Recommended By") {
                        let customPeople = selectedRecommenders.filter { name in
                            !people.contains { $0.name == name }
                        }

                        if !customPeople.isEmpty {
                            ForEach(Array(customPeople).sorted(), id: \.self) { personName in
                                Button {
                                    selectedRecommenders.remove(personName)
                                } label: {
                                    HStack {
                                        Text(personName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                        Image(systemName: "person.badge.plus")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                }
                            }
                        }

                        if !people.isEmpty {
                            ForEach(people) { person in
                                Button {
                                    if selectedRecommenders.contains(person.name) {
                                        selectedRecommenders.remove(person.name)
                                    } else {
                                        selectedRecommenders.insert(person.name)
                                    }
                                } label: {
                                    HStack {
                                        Text(person.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedRecommenders.contains(person.name) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }

                        if people.isEmpty && customPeople.isEmpty {
                            Text("No people selected yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isAdding)
                .opacity(isAdding ? 0.6 : 1.0)

                if isAdding {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Adding movie...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("Add Movie")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                    .disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        isAdding = true
                        onAdd()
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            isAdding = false
                            dismiss()
                        }
                    }
                    .bold()
                    .disabled(selectedRecommenders.isEmpty || isAdding)
                }
            }
        }
    }
}

// MARK: - Offline Add Sheet

private struct OfflineAddMovieSheet: View {
    let title: String
    let people: [Person]
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecommenders: Set<String> = []
    @State private var newPersonName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Movie") {
                    Text(title)
                        .font(.headline)
                }

                Section {
                    HStack {
                        TextField("Add new person", text: $newPersonName)
                            .textInputAutocapitalization(.words)

                        Button {
                            let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            selectedRecommenders.insert(trimmed)
                            newPersonName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.blue)
                        }
                        .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Add New Person")
                }

                Section("Recommended By") {
                    let customPeople = selectedRecommenders.filter { name in
                        !people.contains { $0.name == name }
                    }

                    if !customPeople.isEmpty {
                        ForEach(Array(customPeople).sorted(), id: \.self) { personName in
                            Button {
                                selectedRecommenders.remove(personName)
                            } label: {
                                HStack {
                                    Text(personName)
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    if !people.isEmpty {
                        ForEach(people) { person in
                            Button {
                                if selectedRecommenders.contains(person.name) {
                                    selectedRecommenders.remove(person.name)
                                } else {
                                    selectedRecommenders.insert(person.name)
                                }
                            } label: {
                                HStack {
                                    Text(person.name)
                                    Spacer()
                                    if selectedRecommenders.contains(person.name) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Queue Offline")
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
                    Button("Queue") {
                        onAdd(Array(selectedRecommenders))
                    }
                    .bold()
                    .disabled(selectedRecommenders.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddMoviePageView()
}
