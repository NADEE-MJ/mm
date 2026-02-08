import SwiftUI

// MARK: - Explore Page
// Search and discover new movies

struct ExplorePageView: View {
    @State private var searchText = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var showAddSheet = false
    @State private var selectedMovie: TMDBMovie?
    @State private var recommenderName = ""
    @Environment(ScrollState.self) private var scrollState

    var body: some View {
        NavigationStack {
            VStack {
                if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView(
                        "Search Movies",
                        systemImage: "film",
                        description: Text("Search TMDB for movies to add")
                    )
                } else {
                    List(searchResults) { movie in
                        Button {
                            selectedMovie = movie
                            showAddSheet = true
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
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

                                    if let rating = movie.voteAverage {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                            Text(String(format: "%.1f", rating))
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.yellow)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.blue)
                                    .font(.title2)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search movies")
            .onChange(of: searchText) { _, newValue in
                Task {
                    guard !newValue.isEmpty else {
                        searchResults = []
                        return
                    }
                    
                    isSearching = true
                    // Debounce
                    try? await Task.sleep(for: .milliseconds(500))
                    searchResults = await NetworkService.shared.searchMovies(query: newValue)
                    isSearching = false
                }
            }
            .sheet(isPresented: $showAddSheet) {
                if let movie = selectedMovie {
                    AddMovieSheet(movie: movie, recommenderName: $recommenderName) {
                        Task {
                            _ = await NetworkService.shared.addMovie(
                                tmdbId: movie.id,
                                recommender: recommenderName
                            )
                            showAddSheet = false
                            recommenderName = ""
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Add Movie Sheet

private struct AddMovieSheet: View {
    let movie: TMDBMovie
    @Binding var recommenderName: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Movie info
                HStack(alignment: .top, spacing: 12) {
                    if let url = movie.posterURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        if let year = movie.releaseDate?.prefix(4) {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                // Recommender field
                TextField("Recommender Name", text: $recommenderName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                Spacer()
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle("Add Movie")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                    }
                    .bold()
                    .disabled(recommenderName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ExplorePageView()
}
