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

private struct DiscoverToken: Identifiable, Hashable {
    let kind: DiscoverFilterKind
    let value: String

    var id: String { "\(kind.rawValue):\(value.lowercased())" }
    var displayText: String { "\(kind.label): \(value)" }
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


    func toTokens() -> [DiscoverToken] {
        var result: [DiscoverToken] = []
        result.append(contentsOf: titleValues.map { DiscoverToken(kind: .title, value: $0) })
        result.append(contentsOf: genres.map { DiscoverToken(kind: .genre, value: $0) })
        result.append(contentsOf: actors.map { DiscoverToken(kind: .actor, value: $0) })
        result.append(contentsOf: directors.map { DiscoverToken(kind: .director, value: $0) })
        result.append(contentsOf: years.map { DiscoverToken(kind: .year, value: String($0)) })
        if let minimumRating {
            result.append(DiscoverToken(kind: .rating, value: String(format: "%.1f", minimumRating)))
        }
        return result
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
    @State private var freeText = ""
    @State private var searchTokens: [DiscoverToken] = []
    @State private var scope: DiscoverSearchScope = .discover
    @State private var isSearchPresented = true
    @State private var existingMovieTmdbIds: Set<Int> = []
    @State private var selectedExistingMovie: Movie? = nil
    @State private var showOfflineAddSheet = false
    @State private var selectedPendingMovie: DatabaseManager.PendingMovie?
    @State private var pendingOfflineMovies: [DatabaseManager.PendingMovie] = []
    @State private var discoverNavigation = DiscoverNavigationState.shared
    @State private var handledDiscoverRequestId = 0
    @State private var curatedMoviesByCategory: [DiscoverRailCategory: [TMDBMovie]] = [:]
    @State private var isLoadingCuratedMovies = false
    @State private var didAttemptCuratedLoad = false
    @State private var isKeyboardShowing = false

    init(
        onClose: (() -> Void)? = nil,
        initialSearchType: DiscoverSearchType = .title,
        initialQuery: String = ""
    ) {
        self.onClose = onClose
        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let queryString = trimmed.contains(":") ? trimmed : initialSearchType.prefilledTokenQuery(trimmed)
            let parsed = DiscoverParsedFilters.parse(queryString)
            _freeText = State(initialValue: parsed.freeText)
            _searchTokens = State(initialValue: parsed.toTokens())
            _scope = State(initialValue: parsed.scope)
        }
    }

    private var trimmedSearchTitle: String {
        freeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedFilters: DiscoverParsedFilters {
        var result = DiscoverParsedFilters.parse(freeText)
        result.scope = scope
        for token in searchTokens {
            result.addValue(token.value, for: token.kind)
        }
        return result
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


    private var existingTmdbIdToMovie: [Int: Movie] {
        Dictionary(
            repository.movies.compactMap { movie -> (Int, Movie)? in
                guard let tmdbId = movie.tmdbId else { return nil }
                return (tmdbId, movie)
            },
            uniquingKeysWith: { first, _ in first }
        )
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
                                if existingMovieTmdbIds.contains(selected.id) {
                                    selectedExistingMovie = existingTmdbIdToMovie[selected.id]
                                } else {
                                    selectedMovie = selected
                                }
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
                    } else if searchResults.filter({ $0.mediaType != "person" }).isEmpty && librarySearchResults.isEmpty {
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
                        let addableDiscoverResults = searchResults.filter { $0.mediaType != "person" }
                        if !addableDiscoverResults.isEmpty {
                            Section("Discover Results (\(addableDiscoverResults.count))") {
                                ForEach(addableDiscoverResults) { movie in
                                    let isAlreadyAdded = existingMovieTmdbIds.contains(movie.id)
                                    Button {
                                        if isAlreadyAdded {
                                            selectedExistingMovie = existingTmdbIdToMovie[movie.id]
                                        } else {
                                            selectedMovie = movie
                                        }
                                    } label: {
                                        SearchResultRow(movie: movie, isAlreadyAdded: isAlreadyAdded)
                                    }
                                    .buttonStyle(.plain)
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
                text: $freeText,
                tokens: $searchTokens,
                isPresented: $isSearchPresented,
                prompt: "Search or add filters"
            ) { token in
                Text(token.displayText)
                    .onTapGesture { editToken(token) }
            }
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
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isKeyboardShowing {
                    keyboardToolbarView
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in
                isKeyboardShowing = true
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                isKeyboardShowing = false
            }
            .onAppear {
                isSearchPresented = true
                applyDiscoverNavigationRequest()
            }
            .onChange(of: discoverNavigation.requestId) { _, _ in
                applyDiscoverNavigationRequest()
            }
            .onChange(of: freeText) { _, newText in
                crystallizeIfNeeded(from: newText)
            }
            .task(id: parsedFilters) {
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
                        let result = await repository.addMovieBulk(
                            tmdbId: movie.id,
                            recommenders: Array(selectedRecommenders),
                            mediaType: movie.mediaType
                        )
                        switch result {
                        case .success:
                            _ = await repository.syncPeople(force: true)
                            let peopleResult = await repository.getPeople()
                            switch peopleResult {
                            case .success(let loaded):
                                people = loaded
                            case .failure:
                                people = repository.people
                            }
                            selectedRecommenders = []
                            _ = await repository.getMovies(status: nil)
                            existingMovieTmdbIds = Set(repository.movies.compactMap { $0.tmdbId })
                            return nil
                        case .failure(let error):
                            return error.localizedDescription
                        }
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(item: $selectedPendingMovie) { pendingMovie in
                ResolvePendingMovieSheet(pendingMovie: pendingMovie) { selectedMatch in
                    Task {
                        let result = await repository.resolvePendingMovie(
                            pendingMovieId: pendingMovie.id,
                            tmdbId: selectedMatch.id
                        )

                        _ = result
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
                        pendingOfflineMovies = repository.fetchPendingMovies()
                        showOfflineAddSheet = false
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(item: $selectedExistingMovie) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }

    private func applyDiscoverNavigationRequest() {
        guard discoverNavigation.requestId > handledDiscoverRequestId else { return }
        handledDiscoverRequestId = discoverNavigation.requestId
        let incoming = discoverNavigation.query
        guard !incoming.isEmpty else { return }
        let queryString = incoming.contains(":") ? incoming : discoverNavigation.searchType.prefilledTokenQuery(incoming)
        let parsed = DiscoverParsedFilters.parse(queryString)
        freeText = parsed.freeText
        searchTokens = parsed.toTokens()
        scope = parsed.scope
        isSearchPresented = true
    }

    private func updateScope(_ newScope: DiscoverSearchScope) {
        scope = newScope
    }

    private func insertFilterTokenPrefix(_ kind: DiscoverFilterKind) {
        // Crystallize any complete token already in the text field first
        crystallizeIfNeeded(from: freeText + " ")
        if !freeText.isEmpty && !freeText.hasSuffix(" ") {
            freeText += " "
        }
        freeText += "\(kind.label):"
    }

    private func editToken(_ token: DiscoverToken) {
        searchTokens.removeAll { $0.id == token.id }
        if !freeText.isEmpty && !freeText.hasSuffix(" ") {
            freeText += " "
        }
        freeText += "\(token.kind.label):\(token.value)"
    }

    private func crystallizeIfNeeded(from text: String) {
        guard text.hasSuffix(" ") else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let parsed = DiscoverParsedFilters.parse(trimmed)
        let newTokens = parsed.toTokens()
        guard !newTokens.isEmpty else { return }
        for token in newTokens where !searchTokens.contains(token) {
            searchTokens.append(token)
        }
        freeText = parsed.freeText
    }

    @ViewBuilder
    private var keyboardToolbarView: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(
                        [DiscoverFilterKind.title, .genre, .actor, .director, .year, .rating],
                        id: \.rawValue
                    ) { kind in
                        Button {
                            insertFilterTokenPrefix(kind)
                        } label: {
                            Text("+\(kind.label)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
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
                .padding(.leading, 2)
            }
            .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 6)
                .padding(.horizontal, 8)

            Menu {
                ForEach(DiscoverSearchScope.allCases, id: \.rawValue) { scope in
                    Button {
                        updateScope(scope)
                    } label: {
                        if parsedFilters.scope == scope {
                            Label(scope.label, systemImage: "checkmark")
                        } else {
                            Text(scope.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle")
                    Text(parsedFilters.scope.label)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(AppTheme.blue)
            }
            .padding(.trailing, 2)
        }
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
                HStack(spacing: 8) {
                    Text(movie.title)
                        .font(.headline)

                    if movie.mediaType == "tv" {
                        Text("TV")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppTheme.blue.opacity(0.18))
                            )
                            .foregroundStyle(AppTheme.blue)
                    }
                }

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
                        onSelect(movie)
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
    let onAdd: () async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var errorMessage: String? = nil
    @State private var newPersonName = ""
    @State private var filterText = ""

    private var quickPeople: [Person] { people.filter { $0.isQuick } }
    private var regularPeople: [Person] { people.filter { !$0.isQuick } }
    private var customPeople: [String] {
        Array(selectedRecommenders.filter { name in
            !people.contains { $0.name == name }
        }).sorted()
    }

    private var filteredQuickPeople: [Person] {
        guard !filterText.isEmpty else { return quickPeople }
        return quickPeople.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    private var filteredRegularPeople: [Person] {
        guard !filterText.isEmpty else { return regularPeople }
        return regularPeople.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

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

                    // Add Movie button — above the list
                    Section {
                        Button {
                            errorMessage = nil
                            isAdding = true
                            Task {
                                let error = await onAdd()
                                isAdding = false
                                if let error {
                                    errorMessage = error
                                } else {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isAdding {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(selectedRecommenders.isEmpty
                                         ? "Select a Recommender"
                                         : "Add Movie with \(selectedRecommenders.count) Recommender\(selectedRecommenders.count == 1 ? "" : "s")")
                                        .bold()
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedRecommenders.isEmpty || isAdding)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.footnote)
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

                    // Filter field
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Filter people...", text: $filterText)
                                .autocorrectionDisabled()
                            if !filterText.isEmpty {
                                Button {
                                    filterText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Section("Recommended By") {
                        if !customPeople.isEmpty {
                            ForEach(customPeople, id: \.self) { personName in
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
                        } else if quickPeople.isEmpty && regularPeople.isEmpty {
                            Text("No people selected yet")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !filteredQuickPeople.isEmpty {
                        Section("Quick") {
                            ForEach(filteredQuickPeople) { person in
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
                                        Image(systemName: "bolt.fill")
                                            .foregroundStyle(.purple)
                                            .font(.caption)
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

                    if !filteredRegularPeople.isEmpty {
                        Section("People") {
                            ForEach(filteredRegularPeople) { person in
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
                    }

                    if !filterText.isEmpty && filteredQuickPeople.isEmpty && filteredRegularPeople.isEmpty {
                        Section {
                            Text("No people match \"\(filterText)\"")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
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
            }
            .interactiveDismissDisabled(isAdding)
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
    @State private var filterText = ""

    private var customPeople: [String] {
        Array(selectedRecommenders.filter { name in
            !people.contains { $0.name == name }
        }).sorted()
    }

    private var filteredPeople: [Person] {
        guard !filterText.isEmpty else { return people }
        return people.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movie") {
                    Text(title)
                        .font(.headline)
                }

                // Queue button — above the list
                Section {
                    Button {
                        onAdd(Array(selectedRecommenders))
                    } label: {
                        HStack {
                            Spacer()
                            Text(selectedRecommenders.isEmpty
                                 ? "Select a Recommender"
                                 : "Queue with \(selectedRecommenders.count) Recommender\(selectedRecommenders.count == 1 ? "" : "s")")
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRecommenders.isEmpty)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
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

                // Filter field
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Filter people...", text: $filterText)
                            .autocorrectionDisabled()
                        if !filterText.isEmpty {
                            Button {
                                filterText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Recommended By") {
                    if !customPeople.isEmpty {
                        ForEach(customPeople, id: \.self) { personName in
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

                    if !filteredPeople.isEmpty {
                        ForEach(filteredPeople) { person in
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

                    if !filterText.isEmpty && filteredPeople.isEmpty && customPeople.isEmpty {
                        Text("No people match \"\(filterText)\"")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
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
            }
        }
    }
}

#Preview {
    AddMoviePageView()
}
