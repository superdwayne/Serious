import Foundation

@Observable
final class ScrollState {
    var currentWordIndex: Int = 0
    var isScrolling: Bool = false
    var isPaused: Bool = true
    var isOffScript: Bool = false
    var totalWords: Int = 0

    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(currentWordIndex) / Double(totalWords)
    }

    var isAtEnd: Bool {
        guard totalWords > 0 else { return false }
        return currentWordIndex >= totalWords - 1
    }

    func reset() {
        currentWordIndex = 0
        isScrolling = false
        isPaused = true
        isOffScript = false
    }

    func advanceTo(_ index: Int) {
        guard index >= 0, index < totalWords else { return }
        currentWordIndex = index
    }
}
