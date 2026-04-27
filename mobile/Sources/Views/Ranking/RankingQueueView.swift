import SwiftUI

/// Lists watched movies that haven't been ranked yet.
/// Tapping one opens RankingComparisonView directly — the liked/disliked
/// choice is step 0 inside the sheet.
struct RankingQueueView: View {
    @State private var repository = MovieRepository.shared
    @State private var isLoading = false
    @State private var selectedEntry: UnrankedEntry? = nil

    private var unranked: [UnrankedEntry] { repository.unrankedPool }
    private var ranked: [RankingEntry] { repository.rankedMovies }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if unranked.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up!",
                        systemImage: "trophy.fill",
                        description: Text("Every watched movie has been ranked.")
                    )
                } else {
                    List(unranked) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            HStack(spacing: 12) {
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
                                        .foregroundStyle(.primary)
                                    if let year = entry.year {
                                        Text(year)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Rank Movies")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await load()
            }
            .task {
                await load()
            }
            .sheet(item: $selectedEntry, onDismiss: {
                Task { await load() }
            }) { entry in
                RankingComparisonView(candidate: entry, ranked: ranked)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await repository.fetchRankingData()
    }
}
