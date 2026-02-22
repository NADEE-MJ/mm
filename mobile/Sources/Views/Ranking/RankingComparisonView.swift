import SwiftUI

/// Full-screen ranking sheet.
///
/// Step 0 — Liked / Didn't Like picker (shown first, inside the sheet).
/// Step 1+ — Binary-search comparisons driven by a RankingSession.
/// Completion — Auto-submits and dismisses.
struct RankingComparisonView: View {
    let candidate: UnrankedEntry
    let ranked: [RankingEntry]
    /// When set, removes the existing ranking before inserting (re-rank flow).
    var rerankImdbId: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var activeSession: RankingSession? = nil
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let session = activeSession {
                    progressHeader(session: session)

                    if session.isComplete {
                        completionView(session: session)
                    } else if let midMovie = session.midMovie {
                        comparisonContent(midMovie: midMovie, session: session)
                    }
                } else {
                    likedDislikedPicker
                }

                Spacer()
            }
            .navigationTitle("Rank Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel ranking")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    // MARK: - Step 0: Liked / Didn't Like

    private var likedDislikedPicker: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                CachedAsyncImage(url: candidate.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.secondary.opacity(0.2))
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(candidate.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let year = candidate.year {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 32)

            Text("Did you like this movie?")
                .font(.headline)

            VStack(spacing: 12) {
                Button {
                    startSession(liked: true)
                } label: {
                    Label("Yes, I liked it", systemImage: "hand.thumbsup.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    startSession(liked: false)
                } label: {
                    Label("No, I didn't like it", systemImage: "hand.thumbsdown.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Step 1+: Comparison subviews

    private func progressHeader(session: RankingSession) -> some View {
        VStack(spacing: 6) {
            Text("Step \(session.currentStep) of ~\(session.maxSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(session.stepCount), total: Double(max(session.maxSteps, 1)))
                .tint(.orange)
                .padding(.horizontal)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func comparisonContent(midMovie: RankingEntry, session: RankingSession) -> some View {
        VStack(spacing: 20) {
            Text("Did you enjoy this more than…")
                .font(.headline)
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 16) {
                posterCard(
                    title: candidate.title,
                    year: candidate.year,
                    posterURL: candidate.posterURL,
                    label: "You just watched",
                    labelColor: .orange
                )

                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)

                posterCard(
                    title: midMovie.title,
                    year: midMovie.year,
                    posterURL: midMovie.posterURL,
                    label: "#\(midMovie.position) · \(String(format: "%.1f", midMovie.score))/10",
                    labelColor: .blue
                )
            }
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button {
                    session.answerYes()
                    checkCompletion(session: session)
                } label: {
                    Label("Yes, I liked it more", systemImage: "hand.thumbsup.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    session.answerNo()
                    checkCompletion(session: session)
                } label: {
                    Label("No, I preferred that", systemImage: "hand.thumbsdown.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal)
            .disabled(isSubmitting)
        }
    }

    private func completionView(session: RankingSession) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Ranking Complete!")
                .font(.title2.bold())

            Text("Placing \"\(candidate.title)\" at #\(session.insertionPosition) in your \(session.liked ? "liked" : "disliked") list")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if isSubmitting {
                ProgressView()
            }
        }
        .padding(.top, 40)
        .task {
            await submitRanking(session: session)
        }
    }

    private func posterCard(
        title: String,
        year: String?,
        posterURL: URL?,
        label: String,
        labelColor: Color
    ) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(labelColor)

            CachedAsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.secondary.opacity(0.2))
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.caption.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)

            if let year {
                Text(year)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func startSession(liked: Bool) {
        let session = RankingSession(candidate: candidate, ranked: ranked, liked: liked)
        activeSession = session
        // Empty group — nothing to compare, submit immediately
        if session.isComplete {
            Task { await submitRanking(session: session) }
        }
    }

    private func checkCompletion(session: RankingSession) {
        if session.isComplete {
            Task { await submitRanking(session: session) }
        }
    }

    private func submitRanking(session: RankingSession) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        let result: Result<RankingEntry, RepositoryError>
        if let existingId = rerankImdbId {
            result = await MovieRepository.shared.rerankAtPosition(
                imdbId: existingId,
                position: session.insertionPosition,
                liked: session.liked
            )
        } else {
            result = await MovieRepository.shared.insertAtPosition(
                imdbId: candidate.imdbId,
                position: session.insertionPosition,
                liked: session.liked
            )
        }
        isSubmitting = false
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
