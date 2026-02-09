import SwiftUI

// MARK: - Explore Page
// Search TMDB and add movies with recommender selection.
// Uses debounced search, glass-effect cards, and sheet presentation.

struct ExplorePageView: View {
    var onAccountTap: (() -> Void)? = nil
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var showAddSheet = false
    @State private var selectedMovie: TMDBMovie?
    @State private var recommenderName = ""
    @State private var people: [Person] = []
    @State private var nativeSearchText = "" // For modal/sheet search
    @Environment(ScrollState.self) private var scrollState
    @Environment(SearchState.self) private var searchState
    
    var useNativeSearch: Bool = false // When true, uses native .searchable() for sheets
    
    private var effectiveSearchText: String {
        useNativeSearch ? nativeSearchText : searchState.searchText
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if searchResults.isEmpty && !effectiveSearchText.isEmpty && !isSearching {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Results",
                            subtitle: "Try a different search term."
                        )
                    } else if searchResults.isEmpty && effectiveSearchText.isEmpty {
                        EmptyStateView(
                            icon: "sparkle.magnifyingglass",
                            title: "Discover Movies",
                            subtitle: "Search TMDB for movies to add to your collection."
                        )
                    } else if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        Text("\(searchResults.count) results")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, movie in
                            Button {
                                selectedMovie = movie
                                showAddSheet = true
                            } label: {
                                searchResultRow(movie)
                            }
                            .buttonStyle(.plain)

                            if index < searchResults.count - 1 {
                                Rectangle().fill(AppTheme.stroke).frame(height: 1)
                            }
                        }
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
            .navigationTitle("Explore")
            .modifier(ConditionalSearchable(isActive: useNativeSearch, text: $nativeSearchText))
            .toolbar {
                if let onAccountTap {
                    ToolbarItem(placement: .topBarTrailing) {
                        AccountToolbarButton(action: onAccountTap)
                    }
                }
            }
            .onChange(of: effectiveSearchText) { _, newValue in
                Task {
                    guard !newValue.isEmpty else {
                        searchResults = []
                        return
                    }

                    isSearching = true
                    try? await Task.sleep(for: .milliseconds(500))
                    searchResults = await NetworkService.shared.searchMovies(query: newValue)
                    isSearching = false
                }
            }
            .task {
                await NetworkService.shared.fetchPeople()
                people = NetworkService.shared.people
            }
            .sheet(isPresented: $showAddSheet) {
                if let movie = selectedMovie {
                    AddMovieSheet(
                        movie: movie,
                        recommenderName: $recommenderName,
                        people: people
                    ) {
                        Task {
                            _ = await NetworkService.shared.addMovie(
                                tmdbId: movie.id,
                                recommender: recommenderName
                            )
                            showAddSheet = false
                            recommenderName = ""
                        }
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                }
            }
        }
    }

    // MARK: - Search Result Row

    private func searchResultRow(_ movie: TMDBMovie) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MoviePosterImage(
                url: movie.posterURL,
                width: 60,
                height: 90
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                if let year = movie.releaseDate?.prefix(4) {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let overview = movie.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(2)
                }

                if let rating = movie.voteAverage {
                    StarRatingView(rating)
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppTheme.blue)
                .font(.title2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Add Movie Sheet

private struct AddMovieSheet: View {
    let movie: TMDBMovie
    @Binding var recommenderName: String
    let people: [Person]
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Movie info
                HStack(alignment: .top, spacing: 12) {
                    MoviePosterImage(
                        url: movie.posterURL,
                        width: 80,
                        height: 120
                    )

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
                            StarRatingView(rating)
                        }
                    }
                }

                // Recommender field
                TextField("Recommender Name", text: $recommenderName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                // Quick select from existing people
                if !people.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(people) { person in
                                FilterChip(
                                    title: person.name,
                                    isSelected: recommenderName == person.name
                                ) {
                                    recommenderName = person.name
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                }

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
                    Button("Add") { onAdd() }
                        .bold()
                        .disabled(recommenderName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Conditional Searchable Modifier

private struct ConditionalSearchable: ViewModifier {
    let isActive: Bool
    @Binding var text: String
    
    func body(content: Content) -> some View {
        if isActive {
            content.searchable(text: $text, prompt: "Search movies on TMDB...")
        } else {
            content
        }
    }
}

#Preview {
    ExplorePageView()
}
