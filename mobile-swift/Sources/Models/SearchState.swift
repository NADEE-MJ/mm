import Observation
import SwiftUI

@Observable
class SearchState {
    var searchText = ""
    var isExpanded = false
    
    /// Reset search state
    func reset() {
        searchText = ""
        isExpanded = false
    }
}
