import SwiftUI

struct GlobalSearchPageView: View {
    enum ResultScope: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case people = "People"

        var id: String { rawValue }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case dateWatched = "Date Watched"
        case myRating = "My Rating"
        case tmdbRating = "TMDB Rating"
        case year = "Year"
        case title = "Title"

        var id: String { rawValue }
    }

    var onClose: (() -> Void)? = nil

    @State private var movies: [Movie] = []
    @State private var people: [Person] = []
    @State private var isLoading = false
    @State private var searchText = ""

    @State private var scope: ResultScope = .all
    @State private var sortOption: SortOption = .dateAdded
    @State private var showFilters = false

    @State private var selectedYear: Int?
    @State private var selectedGenre: String?
    @State private var selectedDirector: String?
    @State private var minimumRating: Double = 0

    private var availableYears: [Int] {
        let years = movies.compactMap { movieYear($0) }
        return Array(Set(years)).sorted(by: >)
    }

    private var availableGenres: [String] {
        let genres = movies.flatMap(\.genres)
        return Array(Set(genres.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
            .sorted()
    }

    private var availableDirectors: [String] {
        let directors = movies.compactMap(\.director)
        return Array(Set(directors.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
            .sorted()
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedYear != nil { count += 1 }
        if selectedGenre != nil { count += 1 }
        if selectedDirector != nil { count += 1 }
        if minimumRating > 0 { count += 1 }
        return count
    }

    private var filteredMovies: [Movie] {
        var result = movies
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
            result = result.filter { movie in
                let fields: [String] = [
                    movie.title,
                    movie.overview ?? "",
                    movie.director ?? "",
                    movie.genres.joined(separator: " "),
                    movie.recommendations.map(\.recommender).joined(separator: " "),
                ]
                .map { $0.lowercased() }

                return fields.contains { $0.contains(query) }
            }
        }

        if let selectedYear {
            result = result.filter { movie in
                movieYear(movie) == selectedYear
            }
        }

        if let selectedGenre {
            result = result.filter { movie in
                movie.genres.contains {
                    $0.localizedCaseInsensitiveCompare(selectedGenre) == .orderedSame
                }
            }
        }

        if let selectedDirector {
            result = result.filter { movie in
                (movie.director ?? "").localizedCaseInsensitiveCompare(selectedDirector) == .orderedSame
            }
        }

        if minimumRating > 0 {
            result = result.filter { movie in
                normalizedRating(movie) >= minimumRating
            }
        }

        return sortMovies(result)
    }

    private var filteredPeople: [Person] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return people
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var hasNoResults: Bool {
        switch scope {
        case .all:
            return filteredMovies.isEmpty && filteredPeople.isEmpty
        case .movies:
            return filteredMovies.isEmpty
        case .people:
            return filteredPeople.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Scope", selection: $scope) {
                        ForEach(ResultScope.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isLoading && movies.isEmpty && people.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if hasNoResults {
                    Section {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different search term or adjust filters.")
                        )
                    }
                } else {
                    if scope == .all || scope == .movies {
                        Section("\(filteredMovies.count) movie\(filteredMovies.count == 1 ? "" : "s")") {
                            ForEach(filteredMovies) { movie in
                                GlobalMovieRow(movie: movie)
                            }
                        }
                    }

                    if scope == .all || scope == .people {
                        Section("\(filteredPeople.count) people") {
                            ForEach(filteredPeople) { person in
                                GlobalPersonRow(person: person)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Global Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search movies and people")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption.bold())
                            }
                        }
                    }
                    .accessibilityLabel("Sort and filter")
                }
            }
            .sheet(isPresented: $showFilters) {
                GlobalSearchFiltersSheet(
                    sortOption: $sortOption,
                    selectedYear: $selectedYear,
                    selectedGenre: $selectedGenre,
                    selectedDirector: $selectedDirector,
                    minimumRating: $minimumRating,
                    availableYears: availableYears,
                    availableGenres: availableGenres,
                    availableDirectors: availableDirectors
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func loadData() async {
        isLoading = true
        await NetworkService.shared.fetchMovies()
        await NetworkService.shared.fetchPeople()
        movies = NetworkService.shared.movies
        people = NetworkService.shared.people
        isLoading = false
    }

    private func sortMovies(_ source: [Movie]) -> [Movie] {
        switch sortOption {
        case .title:
            return source.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .year:
            return source.sorted { (movieYear($0) ?? 0) > (movieYear($1) ?? 0) }
        case .tmdbRating:
            return source.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        case .myRating:
            return source.sorted { ($0.myRating ?? 0) > ($1.myRating ?? 0) }
        case .dateWatched:
            return source.sorted { watchedTimestamp($0) > watchedTimestamp($1) }
        case .dateAdded:
            return source.sorted { recommendationTimestamp($0) > recommendationTimestamp($1) }
        }
    }

    private func movieYear(_ movie: Movie) -> Int? {
        let raw = movie.releaseDate ?? ""
        return Int(raw.prefix(4))
    }

    private func normalizedRating(_ movie: Movie) -> Double {
        if let myRating = movie.myRating {
            return Double(myRating)
        }
        return movie.voteAverage ?? 0
    }

    private func watchedTimestamp(_ movie: Movie) -> TimeInterval {
        guard let dateValue = movie.dateWatched else { return 0 }
        return parseISODate(dateValue)?.timeIntervalSince1970 ?? 0
    }

    private func recommendationTimestamp(_ movie: Movie) -> TimeInterval {
        movie.recommendations
            .compactMap { parseISODate($0.dateRecommended)?.timeIntervalSince1970 }
            .max() ?? 0
    }

    private func parseISODate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractionalFormatter.date(from: value) {
            return parsed
        }

        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]
        return basicFormatter.date(from: value)
    }
}

private struct GlobalMovieRow: View {
    let movie: Movie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: movie.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.secondary.opacity(0.2))
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    Color.secondary.opacity(0.2)
                }
            }
            .frame(width: 52, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = movie.releaseDate?.prefix(4) {
                        Text(String(year))
                    }

                    if let rating = movie.voteAverage {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }

                    if let myRating = movie.myRating {
                        Label("\(myRating)", systemImage: "heart.fill")
                            .foregroundStyle(AppTheme.blue)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !movie.genres.isEmpty {
                    Text(movie.genres.prefix(2).joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let director = movie.director, !director.isEmpty {
                    Text("Dir: \(director)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct GlobalPersonRow: View {
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

private struct GlobalSearchFiltersSheet: View {
    @Binding var sortOption: GlobalSearchPageView.SortOption
    @Binding var selectedYear: Int?
    @Binding var selectedGenre: String?
    @Binding var selectedDirector: String?
    @Binding var minimumRating: Double

    let availableYears: [Int]
    let availableGenres: [String]
    let availableDirectors: [String]

    @Environment(\.dismiss) private var dismiss

    private var yearSelection: Binding<String> {
        Binding(
            get: { selectedYear.map(String.init) ?? "__all__" },
            set: { value in
                selectedYear = value == "__all__" ? nil : Int(value)
            }
        )
    }

    private var genreSelection: Binding<String> {
        Binding(
            get: { selectedGenre ?? "__all__" },
            set: { value in
                selectedGenre = value == "__all__" ? nil : value
            }
        )
    }

    private var directorSelection: Binding<String> {
        Binding(
            get: { selectedDirector ?? "__all__" },
            set: { value in
                selectedDirector = value == "__all__" ? nil : value
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(GlobalSearchPageView.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Movie Filters") {
                    Picker("Year", selection: yearSelection) {
                        Text("Any Year").tag("__all__")
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(String(year))
                        }
                    }

                    Picker("Genre", selection: genreSelection) {
                        Text("Any Genre").tag("__all__")
                        ForEach(availableGenres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }

                    Picker("Director", selection: directorSelection) {
                        Text("Any Director").tag("__all__")
                        ForEach(availableDirectors, id: \.self) { director in
                            Text(director).tag(director)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Minimum Rating: \(minimumRating, specifier: "%.1f")")
                        Slider(value: $minimumRating, in: 0...10, step: 0.5)
                    }
                }

                Section {
                    Button("Clear Filters", role: .destructive) {
                        selectedYear = nil
                        selectedGenre = nil
                        selectedDirector = nil
                        minimumRating = 0
                        sortOption = .dateAdded
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
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

#Preview {
    GlobalSearchPageView(onClose: {})
}
