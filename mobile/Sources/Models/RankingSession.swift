import Foundation

/// Manages a single binary-search ranking session for one candidate movie.
///
/// The ranked list is snapshotted once at init, filtered to only the same
/// liked/disliked group, so background syncs can't disturb in-flight comparisons.
@Observable
final class RankingSession {
    let candidate: UnrankedEntry
    let liked: Bool
    private let rankedSnapshot: [RankingEntry]

    private(set) var lo: Int
    private(set) var hi: Int
    private(set) var stepCount: Int

    init(candidate: UnrankedEntry, ranked: [RankingEntry], liked: Bool) {
        self.candidate = candidate
        self.liked = liked
        // Filter snapshot to same liked/disliked group, excluding the candidate itself (for re-ranks)
        self.rankedSnapshot = ranked.filter { $0.liked == liked && $0.imdbId != candidate.imdbId }
        self.lo = 0
        self.hi = self.rankedSnapshot.count
        self.stepCount = 0
    }

    // MARK: - Computed state

    var midIndex: Int { (lo + hi) / 2 }

    var midMovie: RankingEntry? {
        guard !isComplete, rankedSnapshot.indices.contains(midIndex) else { return nil }
        return rankedSnapshot[midIndex]
    }

    var isComplete: Bool { lo >= hi }

    /// 1-indexed insertion position within the liked/disliked group.
    var insertionPosition: Int { lo + 1 }

    var maxSteps: Int {
        let n = rankedSnapshot.count
        guard n > 0 else { return 1 }
        return Int(ceil(log2(Double(n + 1))))
    }

    var currentStep: Int { stepCount + 1 }

    // MARK: - Mutations

    /// YES — candidate is better than midMovie → search left half.
    func answerYes() {
        guard !isComplete else { return }
        hi = midIndex
        stepCount += 1
    }

    /// NO — midMovie is better → search right half.
    func answerNo() {
        guard !isComplete else { return }
        lo = midIndex + 1
        stepCount += 1
    }
}
