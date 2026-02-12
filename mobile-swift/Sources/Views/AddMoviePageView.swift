import SwiftUI

// MARK: - Add Movie Page

struct AddMoviePageView: View {
    let onClose: () -> Void

    @State private var searchResults: [TMDBMovie] = []
    @State private var isLoadingResults = false
    @State private var selectedMovie: TMDBMovie?
    @State private var selectedRecommenders: Set<String> = []
    @State private var people: [Person] = []
    @State private var searchText = ""
    @State private var isSearchPresented = true
    @State private var existingMovieTmdbIds: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                if isLoadingResults {
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
                            let isAlreadyAdded = existingMovieTmdbIds.contains(movie.id)
                            Button {
                                if !isAlreadyAdded {
                                    selectedMovie = movie
                                }
                            } label: {
                                SearchResultRow(movie: movie, isAlreadyAdded: isAlreadyAdded)
                            }
                            .buttonStyle(.plain)
                            .disabled(isAlreadyAdded)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search movies on TMDB")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onClose()
                    }
                    label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Close")
                }
            }
            .task(id: searchText) {
                let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    searchResults = []
                    isLoadingResults = false
                    return
                }

                isLoadingResults = true
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                searchResults = await NetworkService.shared.searchMovies(query: trimmed)
                isLoadingResults = false
            }
            .task {
                await NetworkService.shared.fetchPeople()
                people = NetworkService.shared.people
                await NetworkService.shared.fetchMovies()
                existingMovieTmdbIds = Set(NetworkService.shared.movies.compactMap { $0.tmdbId })
            }
            .sheet(item: $selectedMovie, onDismiss: {
                selectedRecommenders = []
            }) { movie in
                AddMovieSheet(
                    movie: movie,
                    selectedRecommenders: $selectedRecommenders,
                    people: people,
                    onAdd: {
                        Task {
                            _ = await NetworkService.shared.addMovieBulk(
                                tmdbId: movie.id,
                                recommenders: Array(selectedRecommenders)
                            )
                            selectedMovie = nil
                            selectedRecommenders = []
                            // Refresh the existing movies list
                            await NetworkService.shared.fetchMovies()
                            existingMovieTmdbIds = Set(NetworkService.shared.movies.compactMap { $0.tmdbId })
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let movie: TMDBMovie
    let isAlreadyAdded: Bool

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

                if isAlreadyAdded {
                    Label("Already Added", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()
            Image(systemName: isAlreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                .foregroundStyle(isAlreadyAdded ? .green : AppTheme.blue)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Movie Sheet

private struct AddMovieSheet: View {
    let movie: TMDBMovie
    @Binding var selectedRecommenders: Set<String>
    let people: [Person]
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var newPersonName = ""

    var body: some View {
        NavigationStack {
            ZStack {
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

                    Section {
                        HStack {
                            TextField("Add new person", text: $newPersonName)
                                .textInputAutocapitalization(.words)
                            Button {
                                let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                selectedRecommenders.insert(trimmed)
                                newPersonName = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.blue)
                            }
                            .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } header: {
                        Text("Add New Person")
                    } footer: {
                        Text("Type a name and tap + to add")
                    }

                    Section("Recommended By") {
                        // Show selected people (both existing and new)
                        let customPeople = selectedRecommenders.filter { name in
                            !people.contains { $0.name == name }
                        }

                        if !customPeople.isEmpty {
                            ForEach(Array(customPeople).sorted(), id: \.self) { personName in
                                Button {
                                    selectedRecommenders.remove(personName)
                                } label: {
                                    HStack {
                                        Text(personName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                        Image(systemName: "person.badge.plus")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                }
                            }
                        }

                        // Show existing people
                        if !people.isEmpty {
                            ForEach(people) { person in
                                Button {
                                    if selectedRecommenders.contains(person.name) {
                                        selectedRecommenders.remove(person.name)
                                    } else {
                                        selectedRecommenders.insert(person.name)
                                    }
                                } label: {
                                    HStack {
                                        Text(person.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedRecommenders.contains(person.name) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }

                        if people.isEmpty && customPeople.isEmpty {
                            Text("No people selected yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isAdding)
                .opacity(isAdding ? 0.6 : 1.0)

                if isAdding {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Adding movie...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("Add Movie")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                    .disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        isAdding = true
                        onAdd()
                        // Dismiss after a short delay to show the completion
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            isAdding = false
                            dismiss()
                        }
                    }
                    .bold()
                    .disabled(selectedRecommenders.isEmpty || isAdding)
                }
            }
        }
    }
}

#Preview {
    AddMoviePageView(onClose: {})
}
