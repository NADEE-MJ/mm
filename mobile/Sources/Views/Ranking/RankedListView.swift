import SwiftUI

/// Shows liked and disliked sub-lists separately with position badges and scores.
///
/// Liked:    scores (5, 10] — position 1 is best
/// Disliked: scores [1, 5]  — position 1 is least bad
struct RankedListView: View {
    @State private var repository = MovieRepository.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    /// Entry selected for re-ranking — opens RankingComparisonView as a sheet.
    @State private var rerankEntry: RankingEntry? = nil

    private var likedMovies: [RankingEntry] {
        repository.rankedMovies.filter { $0.liked }
    }
    private var dislikedMovies: [RankingEntry] {
        repository.rankedMovies.filter { !$0.liked }
    }

    var body: some View {
        Group {
            if isLoading && repository.rankedMovies.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if likedMovies.isEmpty && dislikedMovies.isEmpty {
                ContentUnavailableView(
                    "No Rankings Yet",
                    systemImage: "list.number",
                    description: Text("Rank your watched movies to build your personal list.")
                )
            } else {
                List {
                    if !likedMovies.isEmpty {
                        Section {
                            ForEach(likedMovies) { entry in
                                rankingRow(entry)
                            }
                        } header: {
                            Label("Liked", systemImage: "hand.thumbsup.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    if !dislikedMovies.isEmpty {
                        Section {
                            ForEach(dislikedMovies) { entry in
                                rankingRow(entry)
                            }
                        } header: {
                            Label("Didn't Like", systemImage: "hand.thumbsdown.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("My Rankings")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .sheet(item: $rerankEntry, onDismiss: {
            Task { await load() }
        }) { entry in
            let candidate = UnrankedEntry(
                imdbId: entry.imdbId,
                title: entry.title,
                posterPath: entry.posterPath,
                year: entry.year
            )
            RankingComparisonView(
                candidate: candidate,
                ranked: repository.rankedMovies,
                rerankImdbId: entry.imdbId
            )
        }
    }

    @ViewBuilder
    private func rankingRow(_ entry: RankingEntry) -> some View {
        HStack(spacing: 12) {
            Text("#\(entry.position)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.blue, in: Capsule())
                .fixedSize()

            CachedAsyncImage(url: entry.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.secondary.opacity(0.2))
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                    Text(String(format: "%.1f/10", entry.score))
                        .font(.caption)
                }
                .foregroundStyle(.blue)
                if let year = entry.year {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await remove(imdbId: entry.imdbId) }
            } label: {
                Label("Remove", systemImage: "trash")
            }

            Button {
                rerankEntry = entry
            } label: {
                Label("Re-rank", systemImage: "arrow.up.arrow.down")
            }
            .tint(.orange)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await repository.fetchRankingData()
    }

    private func remove(imdbId: String) async {
        let result = await repository.removeFromRanking(imdbId: imdbId)
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
