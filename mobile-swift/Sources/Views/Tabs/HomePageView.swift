import SwiftUI

// MARK: - Home Page

struct HomePageView: View {
    @State private var repository = MovieRepository.shared
    @State private var allMovies: [Movie] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var selectedStatus = "to_watch"
    @State private var sortBy = "dateRecommended"
    @State private var showFilters = false
    @State private var filterRecommender: String?
    @State private var filterGenre: String?
    @State private var filterDirector: String?
    @State private var filterActor: String?
    @State private var minimumImdbRating = 0.0
    @State private var minimumRottenTomatoes = 0
    @State private var minimumMetacritic = 0

    private let statusFilters: [(key: String, label: String)] = [
        ("to_watch", "To Watch"),
        ("watched", "Watched"),
    ]

    private var currentDefaultSort: String {
        selectedStatus == "watched" ? "dateWatched" : "dateRecommended"
    }

    private var filteredMovies: [Movie] {
        var result = allMovies.filter { $0.status == selectedStatus }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
            result = result.filter { movie in
                let searchableValues: [String] = [
                    movie.title,
                    movie.overview ?? "",
                    movie.director ?? "",
                    movie.genres.joined(separator: " "),
                    movie.actors.joined(separator: " "),
                    movie.recommendations.map(\.recommender).joined(separator: " "),
                ]
                .map { $0.lowercased() }

                return searchableValues.contains { $0.contains(query) }
            }
        }

        if let recommender = filterRecommender {
            result = result.filter { movie in
                movie.recommendations.contains { $0.recommender == recommender }
            }
        }

        if let genre = filterGenre {
            result = result.filter { movie in
                movie.genres.contains { candidate in
                    candidate.caseInsensitiveCompare(genre) == .orderedSame
                }
            }
        }

        if let director = filterDirector {
            result = result.filter { movie in
                guard let candidate = movie.director else { return false }
                return candidate.caseInsensitiveCompare(director) == .orderedSame
            }
        }

        if let actor = filterActor {
            result = result.filter { movie in
                movie.actors.contains { candidate in
                    candidate.caseInsensitiveCompare(actor) == .orderedSame
                }
            }
        }

        if minimumImdbRating > 0 {
            result = result.filter { movie in
                guard let imdbRating = movie.imdbRating else { return false }
                return imdbRating >= minimumImdbRating
            }
        }

        if minimumRottenTomatoes > 0 {
            result = result.filter { movie in
                guard let rotten = movie.rottenTomatoesRating else { return false }
                return rotten >= minimumRottenTomatoes
            }
        }

        if minimumMetacritic > 0 {
            result = result.filter { movie in
                guard let metacritic = movie.metacriticScore else { return false }
                return metacritic >= minimumMetacritic
            }
        }

        return sortedMovies(result)
    }

    private var allRecommenders: [String] {
        let names = allMovies.flatMap { $0.recommendations.map(\.recommender) }
        return Array(Set(names)).sorted()
    }

    private var allGenres: [String] {
        uniqueSorted(allMovies.flatMap(\.genres))
    }

    private var allDirectors: [String] {
        uniqueSorted(allMovies.compactMap(\.director))
    }

    private var allActors: [String] {
        uniqueSorted(allMovies.flatMap(\.actors))
    }

    private var moviesSectionTitle: String {
        if selectedStatus == "to_watch" {
            return "\(filteredMovies.count) movie\(filteredMovies.count == 1 ? "" : "s") to watch"
        }
        return "\(filteredMovies.count) watched movie\(filteredMovies.count == 1 ? "" : "s")"
    }

    private var toWatchFooterMessage: String? {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard selectedStatus == "to_watch", trimmedQuery.isEmpty else { return nil }

        if filteredMovies.count <= 3 {
            return "Hey, ask your friends for more recommendations."
        }
        if filteredMovies.count >= 12 {
            return "Hey buddy, you got a lot of movies to watch."
        }
        return "Solid queue. Keep chipping away."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(statusFilters, id: \.key) { filter in
                            Text(filter.label).tag(filter.key)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isLoading && allMovies.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if filteredMovies.isEmpty {
                    Section {
                        ContentUnavailableView(
                            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No Movies" : "No Results",
                            systemImage: "film",
                            description: Text(
                                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? (selectedStatus == "to_watch"
                                    ? "Add your first movie to get started."
                                    : "Movies will appear here once watched.")
                                    : "Try a different search term or clear filters."
                            )
                        )
                    }
                } else {
                    Section {
                        ForEach(filteredMovies) { movie in
                            NavigationLink {
                                MovieDetailView(movie: movie)
                            } label: {
                                MovieRowView(movie: movie)
                            }
                            .contextMenu {
                                movieContextMenu(movie)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        _ = await repository.updateMovie(
                                            movie: movie,
                                            rating: nil,
                                            status: "deleted"
                                        )
                                        await loadAllMovies()
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if movie.status == "to_watch" {
                                    Button {
                                        Task {
                                            _ = await repository.updateMovie(
                                                movie: movie,
                                                rating: nil,
                                                status: "watched"
                                            )
                                            await loadAllMovies()
                                        }
                                    } label: {
                                        Label("Watched", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                } else if movie.status == "watched" {
                                    Button {
                                        Task {
                                            _ = await repository.updateMovie(
                                                movie: movie,
                                                rating: nil,
                                                status: "to_watch"
                                            )
                                            await loadAllMovies()
                                        }
                                    } label: {
                                        Label("To Watch", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    } header: {
                        Text(moviesSectionTitle)
                    } footer: {
                        if let toWatchFooterMessage {
                            Text(toWatchFooterMessage)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Movies")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search movies"
            )
            .refreshable {
                await loadAllMovies(forceSync: true)
            }
            .task {
                await loadAllMovies()
            }
            .onAppear {
                Task {
                    await loadAllMovies()
                }
            }
            .onChange(of: selectedStatus) { _, _ in
                if sortBy == "dateRecommended" || sortBy == "dateWatched" {
                    sortBy = currentDefaultSort
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Sort and filter")
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSortSheet(
                    sortBy: $sortBy,
                    filterRecommender: $filterRecommender,
                    filterGenre: $filterGenre,
                    filterDirector: $filterDirector,
                    filterActor: $filterActor,
                    minimumImdbRating: $minimumImdbRating,
                    minimumRottenTomatoes: $minimumRottenTomatoes,
                    minimumMetacritic: $minimumMetacritic,
                    recommenders: allRecommenders,
                    genres: allGenres,
                    directors: allDirectors,
                    actors: allActors,
                    status: selectedStatus
                )
                .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private func movieContextMenu(_ movie: Movie) -> some View {
        if movie.status == "to_watch" {
            Button {
                Task {
                    _ = await repository.updateMovie(
                        movie: movie,
                        rating: nil,
                        status: "watched"
                    )
                    await loadAllMovies()
                }
            } label: {
                Label("Mark Watched", systemImage: "checkmark.circle")
            }
        }

        if movie.status == "watched" {
            Button {
                Task {
                    _ = await repository.updateMovie(
                        movie: movie,
                        rating: nil,
                        status: "to_watch"
                    )
                    await loadAllMovies()
                }
            } label: {
                Label("Move to Watch List", systemImage: "arrow.uturn.backward")
            }
        }

        Button(role: .destructive) {
            Task {
                _ = await repository.updateMovie(
                    movie: movie,
                    rating: nil,
                    status: "deleted"
                )
                await loadAllMovies()
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func loadAllMovies(forceSync: Bool = false) async {
        isLoading = true
        if forceSync {
            _ = await repository.syncMovies(force: true)
        }
        let result = await repository.getMovies(status: nil)
        switch result {
        case .success(let movies):
            allMovies = movies
        case .failure:
            allMovies = repository.movies
        }
        isLoading = false
    }

    private func sortedMovies(_ input: [Movie]) -> [Movie] {
        switch sortBy {
        case "title":
            return input.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case "year":
            return input.sorted {
                let a = Int($0.releaseDate?.prefix(4) ?? "") ?? 0
                let b = Int($1.releaseDate?.prefix(4) ?? "") ?? 0
                return b < a
            }
        case "imdbRating":
            return input.sorted {
                ($0.imdbRating ?? 0) > ($1.imdbRating ?? 0)
            }
        case "rottenTomatoes":
            return input.sorted {
                ($0.rottenTomatoesRating ?? 0) > ($1.rottenTomatoesRating ?? 0)
            }
        case "metacritic":
            return input.sorted {
                ($0.metacriticScore ?? 0) > ($1.metacriticScore ?? 0)
            }
        case "myRating":
            return input.sorted {
                ($0.myRating ?? 0) > ($1.myRating ?? 0)
            }
        default:
            return input
        }
    }

    private func uniqueSorted(_ values: [String]) -> [String] {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}

// MARK: - Movie Row

private struct MovieRowView: View {
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
            .frame(width: 54, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = movie.releaseDate?.prefix(4) {
                        Text(String(year))
                            .foregroundStyle(.secondary)
                    }

                    if let imdbRating = movie.imdbRating {
                        Text("IMDb \(String(format: "%.1f", imdbRating))")
                            .foregroundStyle(.yellow)
                    }

                    if let rottenTomatoes = movie.rottenTomatoesRating {
                        if rottenTomatoes >= 75 {
                            Text("🍅⭐️ \(rottenTomatoes)%")
                        } else if rottenTomatoes >= 60 {
                            Text("🍅 \(rottenTomatoes)%")
                        } else {
                            Text("🤮 \(rottenTomatoes)%")
                        }
                    }

                    if let metacritic = movie.metacriticScore {
                        Label("\(metacritic)", systemImage: "gauge.medium")
                            .foregroundStyle(.orange)
                    }

                    if let myRating = movie.myRating {
                        Label("\(myRating)", systemImage: "heart.fill")
                            .foregroundStyle(AppTheme.blue)
                    }
                }
                .font(.caption)

                if let recommender = movie.recommendations.first(where: { $0.voteType.lowercased() != "downvote" })?.recommender {
                    Text("Upvoted by \(recommender)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let recommender = movie.recommendations.first?.recommender {
                    Text("Downvoted by \(recommender)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Movie Detail View

private struct MovieDetailView: View {
    @State private var currentMovie: Movie
    @State private var ratingValue = 0
    @State private var showRatingSheet = false
    @State private var showAddRecommenderSheet = false
    @State private var showAddDislikeSheet = false
    @State private var people: [Person] = []
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
        List {
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
                .frame(maxWidth: .infinity, minHeight: 260)
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

            Section("Ratings") {
                HStack(spacing: 12) {
                    Text("IMDb")
                    Spacer(minLength: 12)
                    if let imdbRating = currentMovie.imdbRating {
                        Label("\(String(format: "%.1f", imdbRating))/10", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Text("N/A")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("Rotten Tomatoes")
                    Spacer(minLength: 12)
                    if let rottenTomatoes = currentMovie.rottenTomatoesRating {
                        if rottenTomatoes >= 75 {
                            Label("\(rottenTomatoes)%", systemImage: "burst.fill")
                                .foregroundStyle(.green)
                        } else if rottenTomatoes >= 60 {
                            Text("🍅 \(rottenTomatoes)%")
                                .foregroundStyle(.green)
                        } else {
                            Label("\(rottenTomatoes)%", systemImage: "burst.fill")
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("N/A")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("Metacritic")
                    Spacer(minLength: 12)
                    if let metacritic = currentMovie.metacriticScore {
                        Label("\(metacritic)/100", systemImage: "gauge.medium")
                            .foregroundStyle(.orange)
                    } else {
                        Text("N/A")
                            .foregroundStyle(.secondary)
                    }
                }

                if currentMovie.status == "watched" {
                    Stepper("My Rating: \(max(1, ratingValue))/10", value: $ratingValue, in: 1...10)
                        .onChange(of: ratingValue) { _, newValue in
                            Task {
                                _ = await MovieRepository.shared.updateMovie(
                                    movie: currentMovie,
                                    rating: newValue,
                                    status: nil
                                )
                                await refreshCurrentMovie()
                            }
                        }
                } else if let myRating = currentMovie.myRating {
                    LabeledContent("My Rating") {
                        Text("\(myRating)/10")
                    }
                }

                LabeledContent("Upvotes") {
                    Text("\(likedRecommendations.count)")
                }

                LabeledContent("Downvotes") {
                    Text("\(dislikedRecommendations.count)")
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.recommender)
                                .font(.headline)
                            Text("Upvoted \(formattedDate(rec.dateRecommended))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if currentMovie.status == "to_watch" {
                                Button(role: .destructive) {
                                    Task {
                                        await removeRecommender(rec.recommender)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if !dislikedRecommendations.isEmpty {
                Section("Downvoted By") {
                    ForEach(Array(dislikedRecommendations.enumerated()), id: \.offset) { _, rec in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.recommender)
                                .font(.headline)
                            Text("Downvoted \(formattedDate(rec.dateRecommended))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if currentMovie.status == "to_watch" {
                                Button(role: .destructive) {
                                    Task {
                                        await removeRecommender(rec.recommender)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if currentMovie.status == "to_watch" {
                Section {
                    Button {
                        Task {
                            await loadPeople(forceSync: true)
                            showAddRecommenderSheet = true
                        }
                    } label: {
                        Label("Add Upvote", systemImage: "hand.thumbsup.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    Button {
                        Task {
                            await loadPeople(forceSync: true)
                            showAddDislikeSheet = true
                        }
                    } label: {
                        Label("Add Downvote", systemImage: "hand.thumbsdown.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    Button {
                        showRatingSheet = true
                    } label: {
                        Label("Mark as Watched", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .navigationTitle("Details")
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
        .task {
            ratingValue = currentMovie.myRating ?? 7
            await loadPeople()
            await refreshCurrentMovie()
        }
        .sheet(isPresented: $showRatingSheet, onDismiss: {
            Task { await refreshCurrentMovie() }
        }) {
            RatingSheet(movie: currentMovie)
                .presentationDetents([.height(360)])
        }
        .sheet(isPresented: $showAddRecommenderSheet) {
            AddRecommenderSheet(
                people: people,
                existingRecommenders: likedRecommendations.map(\.recommender),
                fallbackPeopleNames: currentMovie.recommendations.map(\.recommender),
                title: "Add Upvote",
                addButtonTitle: "Add Upvote"
            ) { name in
                Task {
                    await addRecommender(name, voteType: "upvote")
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddDislikeSheet) {
            AddRecommenderSheet(
                people: people,
                existingRecommenders: dislikedRecommendations.map(\.recommender),
                fallbackPeopleNames: currentMovie.recommendations.map(\.recommender),
                title: "Add Downvote",
                addButtonTitle: "Add Downvote"
            ) { name in
                Task {
                    await addRecommender(name, voteType: "downvote")
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Movie Details", isPresented: $showFeedbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(feedbackMessage)
        }
    }

    private func formattedDate(_ value: String) -> String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return value
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

    private func loadPeople(forceSync: Bool = false) async {
        if forceSync {
            _ = await MovieRepository.shared.syncPeople(force: true)
        }
        let result = await MovieRepository.shared.getPeople()
        switch result {
        case .success(let loaded):
            people = loaded
        case .failure:
            people = MovieRepository.shared.people
        }
    }

    private func refreshCurrentMovie() async {
        if let cached = MovieRepository.shared.movies.first(where: { $0.imdbId == currentMovie.imdbId }) {
            currentMovie = cached
            if let myRating = cached.myRating {
                ratingValue = myRating
            }
            return
        }

        _ = await MovieRepository.shared.getMovies(status: nil)
        if let refreshed = MovieRepository.shared.movies.first(where: { $0.imdbId == currentMovie.imdbId }) {
            currentMovie = refreshed
            if let myRating = refreshed.myRating {
                ratingValue = myRating
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
            if let myRating = movie.myRating {
                ratingValue = myRating
            }
        case .failure(let error):
            feedbackMessage = error.localizedDescription
            showFeedbackAlert = true
            await refreshCurrentMovie()
        }
    }

    private func addRecommender(_ name: String, voteType: String = "upvote") async {
        let result = await MovieRepository.shared.addRecommender(
            movie: currentMovie,
            recommender: name,
            voteType: voteType
        )
        switch result {
        case .success(let movie):
            currentMovie = movie
            await loadPeople()
        case .failure(.queued(let message)):
            feedbackMessage = message
            showFeedbackAlert = true
            await refreshCurrentMovie()
        case .failure(let error):
            feedbackMessage = error.localizedDescription
            showFeedbackAlert = true
            await refreshCurrentMovie()
        }
    }

    private func removeRecommender(_ name: String) async {
        let result = await MovieRepository.shared.removeRecommender(movie: currentMovie, recommender: name)
        switch result {
        case .success(let movie):
            currentMovie = movie
            await loadPeople()
        case .failure(.queued(let message)):
            feedbackMessage = message
            showFeedbackAlert = true
            await refreshCurrentMovie()
        case .failure(let error):
            feedbackMessage = error.localizedDescription
            showFeedbackAlert = true
            await refreshCurrentMovie()
        }
    }
}

// MARK: - Rating Sheet

private struct RatingSheet: View {
    let movie: Movie
    @State private var selectedRating = 7
    @Environment(\.dismiss) private var dismiss

    init(movie: Movie) {
        self.movie = movie
        _selectedRating = State(initialValue: movie.myRating ?? 7)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Rate \(movie.title)")
                        .font(.headline)
                }

                Section("Rating") {
                    Picker("Score", selection: $selectedRating) {
                        ForEach(1...10, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                Section {
                    Button {
                        Task {
                            _ = await MovieRepository.shared.updateMovie(
                                movie: movie,
                                rating: selectedRating,
                                status: "watched"
                            )
                            dismiss()
                        }
                    } label: {
                        Label("Mark Watched", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Rate Movie")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

// MARK: - Add Recommender Sheet

private struct AddRecommenderSheet: View {
    let people: [Person]
    let existingRecommenders: [String]
    let fallbackPeopleNames: [String]
    let title: String
    let addButtonTitle: String
    let onAdd: (String) -> Void

    @State private var newRecommender = ""
    @Environment(\.dismiss) private var dismiss

    private var trimmedNewRecommender: String {
        newRecommender.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availablePeople: [String] {
        let names = Set(people.map(\.name) + fallbackPeopleNames)
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.filter { candidate in
            !existingRecommenders.contains { existing in
                existing.caseInsensitiveCompare(candidate) == .orderedSame
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Add by Name") {
                    TextField("Person name", text: $newRecommender)
                        .textInputAutocapitalization(.words)

                    Button(addButtonTitle) {
                        onAdd(trimmedNewRecommender)
                        dismiss()
                    }
                    .disabled(trimmedNewRecommender.isEmpty)
                }

                if !availablePeople.isEmpty {
                    Section("Choose Existing") {
                        ForEach(availablePeople, id: \.self) { name in
                            Button {
                                onAdd(name)
                                dismiss()
                            } label: {
                                Text(name)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
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

// MARK: - Filter/Sort Sheet

private struct FilterSortSheet: View {
    @Binding var sortBy: String
    @Binding var filterRecommender: String?
    @Binding var filterGenre: String?
    @Binding var filterDirector: String?
    @Binding var filterActor: String?
    @Binding var minimumImdbRating: Double
    @Binding var minimumRottenTomatoes: Int
    @Binding var minimumMetacritic: Int
    let recommenders: [String]
    let genres: [String]
    let directors: [String]
    let actors: [String]
    let status: String
    @Environment(\.dismiss) private var dismiss

    private var sortOptions: [(key: String, label: String)] {
        if status == "watched" {
            return [
                ("dateWatched", "Date Watched"),
                ("myRating", "My Rating"),
                ("imdbRating", "IMDb Rating"),
                ("rottenTomatoes", "Rotten Tomatoes"),
                ("metacritic", "Metacritic"),
                ("year", "Year"),
                ("title", "Title"),
            ]
        }
        return [
            ("dateRecommended", "Date Added"),
            ("imdbRating", "IMDb Rating"),
            ("rottenTomatoes", "Rotten Tomatoes"),
            ("metacritic", "Metacritic"),
            ("year", "Year"),
            ("title", "Title"),
        ]
    }

    private var recommenderSelection: Binding<String> {
        Binding(
            get: { filterRecommender ?? "__all__" },
            set: { newValue in
                filterRecommender = newValue == "__all__" ? nil : newValue
            }
        )
    }

    private var genreSelection: Binding<String> {
        Binding(
            get: { filterGenre ?? "__all__" },
            set: { newValue in
                filterGenre = newValue == "__all__" ? nil : newValue
            }
        )
    }

    private var directorSelection: Binding<String> {
        Binding(
            get: { filterDirector ?? "__all__" },
            set: { newValue in
                filterDirector = newValue == "__all__" ? nil : newValue
            }
        )
    }

    private var actorSelection: Binding<String> {
        Binding(
            get: { filterActor ?? "__all__" },
            set: { newValue in
                filterActor = newValue == "__all__" ? nil : newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    Picker("Sort By", selection: $sortBy) {
                        ForEach(sortOptions, id: \.key) { option in
                            Text(option.label).tag(option.key)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if !recommenders.isEmpty {
                    Section("Person") {
                        Picker("Person", selection: recommenderSelection) {
                            Text("All People").tag("__all__")
                            ForEach(recommenders, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                if !genres.isEmpty {
                    Section("Genre") {
                        Picker("Genre", selection: genreSelection) {
                            Text("All Genres").tag("__all__")
                            ForEach(genres, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                if !directors.isEmpty {
                    Section("Director") {
                        Picker("Director", selection: directorSelection) {
                            Text("All Directors").tag("__all__")
                            ForEach(directors, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                if !actors.isEmpty {
                    Section("Actor") {
                        Picker("Actor", selection: actorSelection) {
                            Text("All Actors").tag("__all__")
                            ForEach(actors, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                Section("Minimum Scores") {
                    Stepper(value: $minimumImdbRating, in: 0...10, step: 0.5) {
                        if minimumImdbRating == 0 {
                            Text("IMDb: Any")
                        } else {
                            Text("IMDb: \(String(format: "%.1f", minimumImdbRating))+")
                        }
                    }

                    Stepper(value: $minimumRottenTomatoes, in: 0...100, step: 5) {
                        if minimumRottenTomatoes == 0 {
                            Text("Rotten Tomatoes: Any")
                        } else {
                            Text("Rotten Tomatoes: \(minimumRottenTomatoes)%+")
                        }
                    }

                    Stepper(value: $minimumMetacritic, in: 0...100, step: 5) {
                        if minimumMetacritic == 0 {
                            Text("Metacritic: Any")
                        } else {
                            Text("Metacritic: \(minimumMetacritic)+")
                        }
                    }
                }

                Section {
                    Button("Clear All Filters", role: .destructive) {
                        sortBy = status == "watched" ? "dateWatched" : "dateRecommended"
                        filterRecommender = nil
                        filterGenre = nil
                        filterDirector = nil
                        filterActor = nil
                        minimumImdbRating = 0
                        minimumRottenTomatoes = 0
                        minimumMetacritic = 0
                    }
                }
            }
            .navigationTitle("Sort and Filter")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}

// MARK: - Movie Metadata Explorer

struct MovieCreditExplorerView: View {
    let personName: String
    let movies: [Movie]
    let sourceImdbId: String
    let preferredSearchType: DiscoverSearchType

    private var actedMovies: [Movie] {
        let filtered = movies.filter { movie in
            movie.imdbId != sourceImdbId && movie.actors.contains { matches($0, personName) }
        }
        return deduplicatedAndSorted(filtered)
    }

    private var directedMovies: [Movie] {
        let filtered = movies.filter { movie in
            movie.imdbId != sourceImdbId && directorNames(from: movie.director).contains {
                matches($0, personName)
            }
        }
        return deduplicatedAndSorted(filtered)
    }

    var body: some View {
        List {
            Section("Discover") {
                Button {
                    DiscoverNavigationState.shared.open(
                        searchType: preferredSearchType,
                        query: personName
                    )
                } label: {
                    Label("Search TMDB for \(personName)", systemImage: "safari")
                }
            }

            if actedMovies.isEmpty && directedMovies.isEmpty {
                ContentUnavailableView(
                    "No Other Movies",
                    systemImage: "film",
                    description: Text("No other movies for \(personName) in your library yet.")
                )
            }

            if !actedMovies.isEmpty {
                Section("Acted In") {
                    ForEach(actedMovies) { movie in
                        RelatedMovieInfoRow(movie: movie)
                    }
                }
            }

            if !directedMovies.isEmpty {
                Section("Directed") {
                    ForEach(directedMovies) { movie in
                        RelatedMovieInfoRow(movie: movie)
                    }
                }
            }
        }
        .navigationTitle(personName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func matches(_ candidate: String, _ target: String) -> Bool {
        candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(target.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private func directorNames(from value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func deduplicatedAndSorted(_ input: [Movie]) -> [Movie] {
        var byImdb: [String: Movie] = [:]
        for movie in input {
            byImdb[movie.imdbId] = movie
        }

        return byImdb.values.sorted { lhs, rhs in
            let lhsYear = Int(lhs.releaseDate?.prefix(4) ?? "") ?? 0
            let rhsYear = Int(rhs.releaseDate?.prefix(4) ?? "") ?? 0
            if lhsYear != rhsYear {
                return lhsYear > rhsYear
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

struct MovieGenreExplorerView: View {
    let genre: String
    let movies: [Movie]
    let sourceImdbId: String

    private var matchingMovies: [Movie] {
        let filtered = movies.filter { movie in
            movie.imdbId != sourceImdbId && movie.genres.contains { candidate in
                candidate.caseInsensitiveCompare(genre) == .orderedSame
            }
        }

        var byImdb: [String: Movie] = [:]
        for movie in filtered {
            byImdb[movie.imdbId] = movie
        }

        return byImdb.values.sorted { lhs, rhs in
            let lhsYear = Int(lhs.releaseDate?.prefix(4) ?? "") ?? 0
            let rhsYear = Int(rhs.releaseDate?.prefix(4) ?? "") ?? 0
            if lhsYear != rhsYear {
                return lhsYear > rhsYear
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section("Discover") {
                Button {
                    DiscoverNavigationState.shared.open(
                        searchType: .genre,
                        query: genre
                    )
                } label: {
                    Label("Search TMDB for \(genre)", systemImage: "safari")
                }
            }

            if matchingMovies.isEmpty {
                ContentUnavailableView(
                    "No Other Movies",
                    systemImage: "film",
                    description: Text("No other \(genre) movies in your library yet.")
                )
            } else {
                Section("Other \(genre) Movies") {
                    ForEach(matchingMovies) { movie in
                        RelatedMovieInfoRow(movie: movie)
                    }
                }
            }
        }
        .navigationTitle(genre)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RelatedMovieInfoRow: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(movie.title)
                .font(.headline)

            HStack(spacing: 8) {
                if let year = movie.releaseDate?.prefix(4) {
                    Text(String(year))
                        .foregroundStyle(.secondary)
                }

                if let imdbRating = movie.imdbRating {
                    Text("IMDb \(String(format: "%.1f", imdbRating))")
                        .foregroundStyle(.yellow)
                }

                if let rottenTomatoes = movie.rottenTomatoesRating {
                    Text("🍅 \(rottenTomatoes)%")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomePageView()
}
