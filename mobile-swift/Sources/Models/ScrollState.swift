import SwiftUI

@Observable
final class ScrollState {
    var shouldScrollToTop = false
    var isMinimized = false

    func requestScrollToTop() {
        shouldScrollToTop = true
    }

    func resetScrollRequest() {
        shouldScrollToTop = false
    }
    
    func reset() {
        isMinimized = false
    }
}
