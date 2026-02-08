import Observation
import SwiftUI

@Observable
class ScrollState {
    var isMinimized = false

    private var lastOffset: CGFloat = 0
    private var accumulatedDelta: CGFloat = 0

    /// Call from onScrollGeometryChange with the current contentOffset.y.
    /// Collapses after a small downward drag, expands on upward drag or near top.
    func update(offset: CGFloat) {
        let delta = offset - lastOffset

        // Near the top — always show full bar
        if offset < 10 {
            accumulatedDelta = 0
            if isMinimized { isMinimized = false }
            lastOffset = offset
            return
        }

        // Accumulate in the current direction; reset on direction change
        if (delta > 0 && accumulatedDelta < 0) || (delta < 0 && accumulatedDelta > 0) {
            accumulatedDelta = 0
        }
        accumulatedDelta += delta

        // Threshold: 12pt of consistent scroll in one direction
        if accumulatedDelta > 12 && !isMinimized {
            isMinimized = true
            accumulatedDelta = 0
        } else if accumulatedDelta < -12 && isMinimized {
            isMinimized = false
            accumulatedDelta = 0
        }

        lastOffset = offset
    }

    /// Reset when switching tabs.
    func reset() {
        isMinimized = false
        lastOffset = 0
        accumulatedDelta = 0
    }
}
