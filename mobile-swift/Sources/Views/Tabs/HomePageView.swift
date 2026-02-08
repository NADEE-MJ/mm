import SwiftUI

// MARK: - Home Page
// Displays movies list with filtering and sorting

struct HomePageView: View {
    @State private var movies: [Movie] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedStatus = "to_watch"
    @Environment(ScrollState.self) private var scrollState

    private let statuses = [
        ("to_watch", "To Watch"),
        ("watched", "Watched"),
        ("questionable", "Questionable")
    ]

    private var filteredMovies: [Movie] {
        if searchText.isEmpty {
            return movies
        }
        return movies.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status filter
                Picker("Status", selection: $selectedStatus) {
                    ForEach(statuses, id: \.0) { status in
                        Text(status.1).tag(status.0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Movies list
                List {
                    ForEach(filteredMovies) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                        } label: {
                            MovieRowView(movie: movie)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadMovies()
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Movies")
            .searchable(text: $searchText, prompt: "Search movies")
            .task {
                await loadMovies()
            }
            .onChange(of: selectedStatus) { _, _ in
                Task {
                    await loadMovies()
                }
            }
        }
    }

    private func loadMovies() async {
        isLoading = true
        await NetworkService.shared.fetchMovies(status: selectedStatus)
        movies = NetworkService.shared.movies
        isLoading = false
    }
}

// MARK: - Movie Row

private struct MovieRowView: View {
    let movie: Movie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster
            AsyncImage(url: movie.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    Rectangle()
                        .fill(AppTheme.surfaceMuted)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                @unknown default:
                    Rectangle().fill(AppTheme.surfaceMuted)
                }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                if let year = movie.releaseDate?.prefix(4) {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if !movie.recommendations.isEmpty {
                    Text("From \(movie.recommendations[0].recommender)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if let rating = movie.myRating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(rating)/10")
                            .font(.caption)
                    }
                    .foregroundStyle(.yellow)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Movie Detail

private struct MovieDetailView: View {
    let movie: Movie
    @State private var rating: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Poster
                if let url = movie.posterURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    if let overview = movie.overview {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if let voteAverage = movie.voteAverage {
                        HStack {
                            Image(systemName: "star.fill")
                            Text(String(format: "%.1f/10", voteAverage))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.yellow)
                    }

                    // Recommenders
                    if !movie.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommended by:")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            ForEach(movie.recommendations, id: \.recommender) { rec in
                                Text("• \(rec.recommender)")
                                    .font(.body)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Rating
                    if movie.status == "watched" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Rating:")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            HStack {
                                ForEach(1...10, id: \.self) { value in
                                    Button {
                                        rating = value
                                        Task {
                                            await NetworkService.shared.updateMovie(
                                                id: movie.id,
                                                rating: value,
                                                status: nil
                                            )
                                        }
                                    } label: {
                                        Text("\(value)")
                                            .font(.caption)
                                            .foregroundStyle(
                                                (rating ?? movie.myRating ?? 0) >= value
                                                    ? .white : AppTheme.textTertiary
                                            )
                                            .frame(width: 28, height: 28)
                                            .background(
                                                (rating ?? movie.myRating ?? 0) >= value
                                                    ? AppTheme.blue : AppTheme.surface,
                                                in: .circle
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rating = movie.myRating
        }
    }
}

#Preview {
    HomePageView()
}
