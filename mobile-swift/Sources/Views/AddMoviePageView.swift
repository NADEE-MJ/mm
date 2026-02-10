import SwiftUI

// MARK: - Add Movie Page

struct AddMoviePageView: View {
    let onClose: () -> Void

    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var selectedMovie: TMDBMovie?
    @State private var recommenderName = ""
    @State private var people: [Person] = []
    @State private var searchText = ""

    @Environment(ScrollState.self) private var scrollState

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if searchResults.isEmpty && searchText.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Add Movie",
                            systemImage: "sparkle.magnifyingglass",
                            description: Text("Search TMDB for movies to add to your collection.")
                        )
                    }
                } else if searchResults.isEmpty {
                    Section {
                        ContentUnavailableView.search
                    }
                } else {
                    Section("\(searchResults.count) results") {
                        ForEach(searchResults) { movie in
                            Button {
                                selectedMovie = movie
                            } label: {
                                SearchResultRow(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.update(offset: offset)
                }
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search movies on TMDB")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onClose()
                    }
                    label: { Text("Close") }
                }
            }
            .task(id: searchText) {
                let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    searchResults = []
                    isSearching = false
                    return
                }

                isSearching = true
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                searchResults = await NetworkService.shared.searchMovies(query: trimmed)
                isSearching = false
            }
            .task {
                await NetworkService.shared.fetchPeople()
                people = NetworkService.shared.people
            }
            .sheet(item: $selectedMovie, onDismiss: {
                recommenderName = ""
            }) { movie in
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
                        selectedMovie = nil
                        recommenderName = ""
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let movie: TMDBMovie

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
            .frame(width: 56, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)

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
            }

            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppTheme.blue)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Movie Sheet

private struct AddMovieSheet: View {
    let movie: TMDBMovie
    @Binding var recommenderName: String
    let people: [Person]
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var recommenderSelection: Binding<String> {
        Binding(
            get: { people.contains(where: { $0.name == recommenderName }) ? recommenderName : "" },
            set: { recommenderName = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movie") {
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

                Section("Person") {
                    TextField("Recommended by", text: $recommenderName)

                    if !people.isEmpty {
                        Picker("Choose Existing", selection: recommenderSelection) {
                            Text("Manual Entry").tag("")
                            ForEach(people) { person in
                                Text(person.name).tag(person.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Movie")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd() }
                        .bold()
                        .disabled(recommenderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddMoviePageView(onClose: {})
}
