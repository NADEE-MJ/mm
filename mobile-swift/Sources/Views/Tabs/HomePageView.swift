import SwiftUI

// MARK: - Home Page

struct HomePageView: View {
    var onAddMovieTap: (() -> Void)? = nil
    var onAccountTap: (() -> Void)? = nil

    @State private var allMovies: [Movie] = []
    @State private var isLoading = false
    @State private var selectedStatus = "to_watch"
    @State private var sortBy = "dateRecommended"
    @State private var showFilters = false
    @State private var filterRecommender: String?

    private let statusFilters: [(key: String, label: String)] = [
        ("to_watch", "To Watch"),
        ("watched", "Watched"),
    ]

    private var currentDefaultSort: String {
        selectedStatus == "watched" ? "dateWatched" : "dateRecommended"
    }

    private var filteredMovies: [Movie] {
        var result = allMovies.filter { $0.status == selectedStatus }

        if let recommender = filterRecommender {
            result = result.filter { movie in
                movie.recommendations.contains { $0.recommender == recommender }
            }
        }

        return sortedMovies(result)
    }

    private var allRecommenders: [String] {
        let names = allMovies.flatMap { $0.recommendations.map(\.recommender) }
        return Array(Set(names)).sorted()
    }

    private var moviesSectionTitle: String {
        if selectedStatus == "to_watch" {
            return "\(filteredMovies.count) movie\(filteredMovies.count == 1 ? "" : "s") to watch"
        }
        return "\(filteredMovies.count) watched movie\(filteredMovies.count == 1 ? "" : "s")"
    }

    private var toWatchFooterMessage: String? {
        guard selectedStatus == "to_watch" else { return nil }

        if filteredMovies.count <= 3 {
            return "Hey, ask your friends for more recommendations."
        }
        if filteredMovies.count >= 12 {
            return "Hey buddy, you got a lot of movies to watch."
        }
        return "Solid queue. Keep chipping away."
    }

    private var activeFiltersCount: Int {
        [filterRecommender].compactMap { $0 }.count
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

                    Button {
                        showFilters = true
                    } label: {
                        HStack {
                            Label("Sort and Filter", systemImage: "line.3.horizontal.decrease.circle")
                            Spacer()
                            if activeFiltersCount > 0 {
                                Text("\(activeFiltersCount)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
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
                            "No Movies",
                            systemImage: "film",
                            description: Text(
                                selectedStatus == "to_watch"
                                    ? "Add your first movie to get started."
                                    : "Movies will appear here once watched."
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
                                        await NetworkService.shared.updateMovie(
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
                                            await NetworkService.shared.updateMovie(
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
                                            await NetworkService.shared.updateMovie(
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
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadAllMovies()
            }
            .task {
                await loadAllMovies()
            }
            .onChange(of: selectedStatus) { _, _ in
                if sortBy == "dateRecommended" || sortBy == "dateWatched" {
                    sortBy = currentDefaultSort
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let onAddMovieTap {
                        Button(action: onAddMovieTap) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add movie")
                    }

                    if let onAccountTap {
                        Button(action: onAccountTap) {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Open account")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSortSheet(
                    sortBy: $sortBy,
                    filterRecommender: $filterRecommender,
                    recommenders: allRecommenders,
                    status: selectedStatus
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private func movieContextMenu(_ movie: Movie) -> some View {
        if movie.status == "to_watch" {
            Button {
                Task {
                    await NetworkService.shared.updateMovie(
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
                    await NetworkService.shared.updateMovie(
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
                await NetworkService.shared.updateMovie(
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

    private func loadAllMovies() async {
        isLoading = true
        await NetworkService.shared.fetchMovies()
        allMovies = NetworkService.shared.movies
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

// MARK: - Movie Row

private struct MovieRowView: View {
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

                if let recommender = movie.recommendations.first?.recommender {
                    Text("Recommended by \(recommender)")
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
    let movie: Movie
    @State private var ratingValue = 0
    @State private var showRatingSheet = false

    var body: some View {
        List {
            Section {
                AsyncImage(url: movie.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure, .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.secondary.opacity(0.15))
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    @unknown default:
                        Color.secondary.opacity(0.15)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Section("Details") {
                LabeledContent("Title") {
                    Text(movie.title)
                }

                if let year = movie.releaseDate?.prefix(4) {
                    LabeledContent("Year") {
                        Text(String(year))
                    }
                }

                LabeledContent("Status") {
                    Text(movie.status == "to_watch" ? "To Watch" : "Watched")
                }
            }

            Section("Ratings") {
                if let vote = movie.voteAverage {
                    LabeledContent("TMDB") {
                        Label(String(format: "%.1f", vote), systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                if movie.status == "watched" {
                    Stepper("My Rating: \(max(1, ratingValue))/10", value: $ratingValue, in: 1...10)
                        .onChange(of: ratingValue) { _, newValue in
                            Task {
                                await NetworkService.shared.updateMovie(
                                    movie: movie,
                                    rating: newValue,
                                    status: nil
                                )
                            }
                        }
                } else if let myRating = movie.myRating {
                    LabeledContent("My Rating") {
                        Text("\(myRating)/10")
                    }
                }

                LabeledContent("Recommendations") {
                    Text("\(movie.recommendations.count)")
                }
            }

            if let overview = movie.overview, !overview.isEmpty {
                Section("Overview") {
                    Text(overview)
                }
            }

            if !movie.recommendations.isEmpty {
                Section("Recommended By") {
                    ForEach(Array(movie.recommendations.enumerated()), id: \.offset) { _, rec in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.recommender)
                                .font(.headline)
                            Text("Recommended \(formattedDate(rec.dateRecommended))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if movie.status == "to_watch" {
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
        .onAppear { ratingValue = movie.myRating ?? 7 }
        .sheet(isPresented: $showRatingSheet) {
            RatingSheet(movie: movie)
                .presentationDetents([.height(360)])
        }
    }

    private func formattedDate(_ value: String) -> String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return value
    }
}

// MARK: - Rating Sheet

private struct RatingSheet: View {
    let movie: Movie
    @State private var selectedRating = 7
    @Environment(\.dismiss) private var dismiss

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
                            await NetworkService.shared.updateMovie(
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

    private var recommenderSelection: Binding<String> {
        Binding(
            get: { filterRecommender ?? "__all__" },
            set: { newValue in
                filterRecommender = newValue == "__all__" ? nil : newValue
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

                Section {
                    Button("Clear All Filters", role: .destructive) {
                        sortBy = status == "watched" ? "dateWatched" : "dateRecommended"
                        filterRecommender = nil
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

#Preview {
    HomePageView()
}
