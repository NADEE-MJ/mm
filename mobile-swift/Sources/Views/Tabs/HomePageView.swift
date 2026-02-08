import SwiftUI

// MARK: - Home Page
// Movie browsing with To Watch / Watched tabs, poster grid,
// filter chips, sort/filter sheet, swipe actions, pull-to-refresh.

struct HomePageView: View {
    @State private var movies: [Movie] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedStatus = "to_watch"
    @State private var sortBy = "dateRecommended"
    @State private var showFilters = false
    @State private var filterRecommender: String?
    @Environment(ScrollState.self) private var scrollState

    private let statusFilters: [(key: String, label: String)] = [
        ("to_watch", "To Watch"),
        ("watched", "Watched"),
    ]

    // MARK: - Computed

    private var filteredMovies: [Movie] {
        var result = movies

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let recommender = filterRecommender {
            result = result.filter { movie in
                movie.recommendations.contains { $0.recommender == recommender }
            }
        }

        return sortedMovies(result)
    }

    private var allRecommenders: [String] {
        let names = movies.flatMap { $0.recommendations.map(\.recommender) }
        return Array(Set(names)).sorted()
    }

    private var toWatchCount: Int {
        movies.filter { $0.status == "to_watch" }.count
    }

    private var watchedCount: Int {
        movies.filter { $0.status == "watched" }.count
    }

    private var activeFiltersCount: Int {
        [filterRecommender].compactMap { $0 }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    // Status filter chips
                    statusFilterBar

                    // Sort & filter bar
                    sortFilterBar

                    // Movie grid or empty state
                    if filteredMovies.isEmpty {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else {
                            EmptyStateView(
                                icon: "film",
                                title: searchText.isEmpty ? "No Movies" : "No Results",
                                subtitle: searchText.isEmpty
                                    ? (selectedStatus == "to_watch"
                                        ? "Add your first movie to get started."
                                        : "Movies will appear here once watched.")
                                    : "Try a different search term or filter."
                            )
                        }
                    } else {
                        movieGrid
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.update(offset: offset)
                }
            }
            .background { PageBackground() }
            .navigationTitle("Movies")
            .searchable(text: $searchText, prompt: "Search movies...")
            .refreshable {
                await loadMovies()
            }
            .task {
                await loadAllMovies()
            }
            .onChange(of: selectedStatus) { _, _ in
                Task { await loadMovies() }
            }
            .sheet(isPresented: $showFilters) {
                FilterSortSheet(
                    sortBy: $sortBy,
                    filterRecommender: $filterRecommender,
                    recommenders: allRecommenders,
                    status: selectedStatus
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
    }

    // MARK: - Status Filter Bar

    private var statusFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(statusFilters, id: \.key) { filter in
                    FilterChip(
                        title: "\(filter.label) (\(filter.key == "to_watch" ? toWatchCount : watchedCount))",
                        isSelected: selectedStatus == filter.key
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedStatus = filter.key
                            sortBy = filter.key == "watched" ? "dateWatched" : "dateRecommended"
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    // MARK: - Sort & Filter Bar

    private var sortFilterBar: some View {
        HStack {
            Text("\(filteredMovies.count) movies")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                showFilters = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14))
                    Text("Filter")
                        .font(.subheadline.weight(.medium))
                    if activeFiltersCount > 0 {
                        BadgeView(count: activeFiltersCount)
                    }
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Movie Grid

    private var movieGrid: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 110))], spacing: 16) {
            ForEach(filteredMovies) { movie in
                NavigationLink {
                    MovieDetailView(movie: movie)
                } label: {
                    MoviePosterCard(movie: movie)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    movieContextMenu(movie)
                }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func movieContextMenu(_ movie: Movie) -> some View {
        if movie.status == "to_watch" {
            Button {
                Task {
                    await NetworkService.shared.updateMovie(
                        movie: movie, rating: nil, status: "watched"
                    )
                    await loadMovies()
                }
            } label: {
                Label("Mark Watched", systemImage: "checkmark.circle")
            }
        }

        if movie.status == "watched" {
            Button {
                Task {
                    await NetworkService.shared.updateMovie(
                        movie: movie, rating: nil, status: "to_watch"
                    )
                    await loadMovies()
                }
            } label: {
                Label("Move to Watch List", systemImage: "arrow.uturn.backward")
            }
        }

        Button(role: .destructive) {
            Task {
                await NetworkService.shared.updateMovie(
                    movie: movie, rating: nil, status: "deleted"
                )
                await loadMovies()
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Data

    private func loadAllMovies() async {
        isLoading = true
        await NetworkService.shared.fetchMovies()
        movies = NetworkService.shared.movies
        isLoading = false
    }

    private func loadMovies() async {
        isLoading = true
        await NetworkService.shared.fetchMovies(status: selectedStatus)
        movies = NetworkService.shared.movies
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
        case "rating":
            return input.sorted {
                ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0)
            }
        case "myRating":
            return input.sorted {
                ($0.myRating ?? 0) > ($1.myRating ?? 0)
            }
        default:
            return input
        }
    }
}

// MARK: - Movie Poster Card

private struct MoviePosterCard: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MoviePosterImage(
                url: movie.posterURL,
                width: .infinity,
                height: 165
            )
            .frame(maxWidth: .infinity)

            Text(movie.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let year = movie.releaseDate?.prefix(4) {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if let rating = movie.voteAverage {
                    StarRatingView(rating)
                }

                Spacer()

                if let myRating = movie.myRating {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                        Text("\(myRating)")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.blue)
                }
            }

            if let recommender = movie.recommendations.first?.recommender {
                Text("from \(recommender)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Movie Detail View

private struct MovieDetailView: View {
    let movie: Movie
    @State private var rating: Int?
    @State private var showRatingSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Poster
                MoviePosterImage(
                    url: movie.posterURL,
                    width: .infinity,
                    height: 350
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    // Title & Year
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.textPrimary)

                        if let year = movie.releaseDate?.prefix(4) {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    // Ratings row
                    if movie.voteAverage != nil || movie.myRating != nil {
                        FrostedCard {
                            HStack(spacing: 0) {
                                if let vote = movie.voteAverage {
                                    statCell(
                                        value: String(format: "%.1f", vote),
                                        label: "TMDB",
                                        icon: "star.fill"
                                    )
                                }
                                if let myRating = movie.myRating {
                                    statCell(
                                        value: "\(myRating)/10",
                                        label: "My Rating",
                                        icon: "heart.fill"
                                    )
                                }
                                statCell(
                                    value: "\(movie.recommendations.count)",
                                    label: "Votes",
                                    icon: "hand.thumbsup.fill"
                                )
                            }
                            .padding(.vertical, 12)
                        }
                    }

                    // Overview
                    if let overview = movie.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Overview")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(overview)
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    // Recommenders
                    if !movie.recommendations.isEmpty {
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(movie.recommendations.enumerated()), id: \.element.recommender) { index, rec in
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rec.recommender)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text("Recommended \(rec.dateRecommended)")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textTertiary)
                                        }
                                        Spacer()
                                    }
                                    .padding(14)

                                    if index < movie.recommendations.count - 1 {
                                        DividerLine()
                                    }
                                }
                            }
                        }
                    }

                    // Actions
                    if movie.status == "to_watch" {
                        Button {
                            showRatingSheet = true
                        } label: {
                            Label("Mark as Watched", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.blue)
                    }

                    // Rating editor for watched movies
                    if movie.status == "watched" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Rating")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            HStack(spacing: 6) {
                                ForEach(1...10, id: \.self) { value in
                                    Button {
                                        rating = value
                                        Task {
                                            await NetworkService.shared.updateMovie(
                                                movie: movie, rating: value, status: nil
                                            )
                                        }
                                    } label: {
                                        Text("\(value)")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(
                                                (rating ?? movie.myRating ?? 0) >= value
                                                    ? .white : AppTheme.textTertiary
                                            )
                                            .frame(width: 30, height: 30)
                                            .background(
                                                (rating ?? movie.myRating ?? 0) >= value
                                                    ? AppTheme.blue : AppTheme.surface,
                                                in: .circle
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background { PageBackground() }
        .navigationTitle("Details")
        .toolbarTitleDisplayMode(.inline)
        .onAppear { rating = movie.myRating }
        .sheet(isPresented: $showRatingSheet) {
            RatingSheet(movie: movie)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
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

// MARK: - Rating Sheet

private struct RatingSheet: View {
    let movie: Movie
    @State private var selectedRating = 7
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Rate \(movie.title)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { value in
                        Button {
                            selectedRating = value
                        } label: {
                            Text("\(value)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(
                                    selectedRating >= value ? .white : AppTheme.textTertiary
                                )
                                .frame(width: 34, height: 34)
                                .background(
                                    selectedRating >= value ? AppTheme.blue : AppTheme.surface,
                                    in: .circle
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    Task {
                        await NetworkService.shared.updateMovie(
                            movie: movie, rating: selectedRating, status: "watched"
                        )
                        dismiss()
                    }
                } label: {
                    Label("Mark Watched", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)

                Spacer()
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle("Rate Movie")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Filter/Sort Sheet

private struct FilterSortSheet: View {
    @Binding var sortBy: String
    @Binding var filterRecommender: String?
    let recommenders: [String]
    let status: String
    @Environment(\.dismiss) private var dismiss

    private var sortOptions: [(key: String, label: String)] {
        if status == "watched" {
            return [
                ("dateWatched", "Date Watched"),
                ("myRating", "My Rating"),
                ("rating", "TMDB Rating"),
                ("year", "Year"),
                ("title", "Title"),
            ]
        }
        return [
            ("dateRecommended", "Date Added"),
            ("rating", "TMDB Rating"),
            ("year", "Year"),
            ("title", "Title"),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                // Sort section
                Section("Sort By") {
                    ForEach(sortOptions, id: \.key) { option in
                        Button {
                            sortBy = option.key
                        } label: {
                            HStack {
                                Text(option.label)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if sortBy == option.key {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.blue)
                                }
                            }
                        }
                    }
                }

                // Recommender filter
                if !recommenders.isEmpty {
                    Section("Recommender") {
                        Button {
                            filterRecommender = nil
                        } label: {
                            HStack {
                                Text("All Recommenders")
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if filterRecommender == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.blue)
                                }
                            }
                        }

                        ForEach(recommenders, id: \.self) { name in
                            Button {
                                filterRecommender = name
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    if filterRecommender == name {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // Clear all
                Section {
                    Button("Clear All Filters") {
                        sortBy = status == "watched" ? "dateWatched" : "dateRecommended"
                        filterRecommender = nil
                    }
                    .foregroundStyle(.red)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sort & Filter")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}

#Preview {
    HomePageView()
}
