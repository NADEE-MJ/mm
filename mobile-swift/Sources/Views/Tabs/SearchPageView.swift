import SwiftUI

// MARK: - Search Page
// Dedicated search screen used by the floating search button.

struct SearchPageView: View {
    @State private var movies: [Movie] = []
    @State private var people: [Person] = []
    @State private var isLoading = false
    @Environment(ScrollState.self) private var scrollState
    @Environment(SearchState.self) private var searchState

    var onAccountTap: (() -> Void)? = nil
    var onBackgroundTap: (() -> Void)? = nil

    private var query: String {
        searchState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasQuery: Bool { !query.isEmpty }

    private var filteredMovies: [Movie] {
        guard hasQuery else { return recentsMovies }
        return movies.filter { $0.title.localizedCaseInsensitiveContains(query) }.prefix(16).map { $0 }
    }

    private var filteredPeople: [Person] {
        guard hasQuery else { return recentsPeople }
        return people.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(12).map { $0 }
    }

    private var recentsMovies: [Movie] {
        movies.prefix(8).map { $0 }
    }

    private var recentsPeople: [Person] {
        people.prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if filteredMovies.isEmpty && filteredPeople.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: hasQuery ? "No Results" : "Search",
                            subtitle: hasQuery
                                ? "Try a different term."
                                : "Search movies and people."
                        )
                    } else {
                        if !filteredMovies.isEmpty {
                            searchSection("Movies", systemImage: "film.fill") {
                                ForEach(filteredMovies) { movie in
                                    searchRow(
                                        icon: "film.fill",
                                        title: movie.title,
                                        subtitle: movie.releaseDate?.prefix(4).map { String($0) } ?? "Movie"
                                    )
                                }
                            }
                        }

                        if !filteredPeople.isEmpty {
                            searchSection("People", systemImage: "person.2.fill") {
                                ForEach(filteredPeople) { person in
                                    searchRow(
                                        icon: "person.fill",
                                        title: person.name,
                                        subtitle: person.isTrusted ? "Trusted recommender" : "Recommender"
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
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
            .background {
                PageBackground()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBackgroundTap?()
                    }
            }
            .navigationTitle("Search")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .toolbar {
                if let onAccountTap {
                    ToolbarItem(placement: .topBarTrailing) {
                        AccountToolbarButton(action: onAccountTap)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func searchSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            FrostedCard {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private func searchRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        async let fetchMoviesTask = NetworkService.shared.fetchMovies()
        async let fetchPeopleTask = NetworkService.shared.fetchPeople()
        _ = await (fetchMoviesTask, fetchPeopleTask)
        movies = NetworkService.shared.movies
        people = NetworkService.shared.people
        isLoading = false
    }
}

#Preview {
    SearchPageView()
}
