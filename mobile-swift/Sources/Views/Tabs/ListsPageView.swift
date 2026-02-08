import SwiftUI

// MARK: - Lists Page
// Displays movie lists (To Watch, Watched, etc.)

struct ListsPageView: View {
    @State private var movies: [Movie] = []
    @Environment(ScrollState.self) private var scrollState

    private var groupedMovies: [(String, [Movie])] {
        let statuses = [
            ("To Watch", "to_watch"),
            ("Watched", "watched"),
            ("Questionable", "questionable")
        ]
        
        return statuses.compactMap { (title, status) in
            let filtered = movies.filter { $0.status == status }
            return filtered.isEmpty ? nil : (title, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedMovies, id: \.0) { section in
                    Section(section.0) {
                        ForEach(section.1) { movie in
                            NavigationLink {
                                Text(movie.title)
                            } label: {
                                HStack {
                                    Text(movie.title)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    if let rating = movie.myRating {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                            Text("\(rating)")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.yellow)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(AppTheme.background)
            .navigationTitle("Lists")
            .refreshable {
                await loadMovies()
            }
            .task {
                await loadMovies()
            }
        }
    }

    private func loadMovies() async {
        await NetworkService.shared.fetchMovies()
        movies = NetworkService.shared.movies
    }
}

#Preview {
    ListsPageView()
}
