import Foundation

@Observable
final class WordMatcher {
    var currentPosition: Int = 0
    private(set) var consecutiveMisses: Int = 0
    private var scriptWords: [ScriptWord] = []
    private var sensitivity: Double = 0.7
    private var candidatePosition: Int?
    private var candidateHits: Int = 0

    var isOffScript: Bool {
        consecutiveMisses >= Constants.offScriptThreshold
    }

    func configure(script: Script, sensitivity: Double) {
        self.scriptWords = script.words
        self.sensitivity = sensitivity
        self.currentPosition = 0
        self.consecutiveMisses = 0
        resetCandidate()
    }

    func processTranscription(_ result: TranscriptionResult) -> Int? {
        guard !scriptWords.isEmpty else { return nil }
        let spokenWords = result.words
            .map { $0.normalizedForMatching }
            .filter { !$0.isEmpty }

        // Require minimum spoken words to avoid unreliable single-word
        // matches after speech-session restarts or at transcription start
        guard spokenWords.count >= Constants.minWordsForMatch else { return nil }

        let ahead = isOffScript ? Constants.offScriptSearchAhead : Constants.searchWindowAhead
        let windowStart = max(0, currentPosition - Constants.searchWindowBack)
        let windowEnd = min(scriptWords.count - 1, currentPosition + ahead)
        guard windowStart <= windowEnd else { return nil }

        var bestMatchIndex: Int?
        var bestScore: Double = 0.0

        // ── 1) Phrase matching (primary — most reliable) ──
        if spokenWords.count >= 2 {
            if let phraseResult = matchPhrase(spokenWords: spokenWords, startingNear: currentPosition),
               phraseResult.score >= sensitivity {
                bestMatchIndex = phraseResult.endIndex
                bestScore = phraseResult.score
            }
        }

        // ── 2) Single-word fallback with forward-biased window ──
        if bestMatchIndex == nil {
            let lastSpoken = spokenWords.last!
            let tightEnd = min(scriptWords.count - 1, currentPosition + Constants.maxStepForward)
            let singleWordThreshold = sensitivity + 0.05  // Slightly stricter for single words

            for i in windowStart...tightEnd {
                let scriptWord = scriptWords[i].normalized
                var score = StringSimilarity.normalizedSimilarity(lastSpoken, scriptWord)

                let offset = i - currentPosition
                if offset >= 1 && offset <= 3 {
                    score += 0.05
                } else if offset < 0 {
                    score *= 0.9
                }

                if score > bestScore && score >= singleWordThreshold {
                    bestScore = score
                    bestMatchIndex = i
                }
            }
        }

        guard let matchIndex = bestMatchIndex else {
            consecutiveMisses += 1
            return nil
        }

        // ── 3) Gate large jumps — require consecutive confirmations ──
        // Only gate backwards jumps and very large forward jumps
        let jump = matchIndex - currentPosition
        let needsConfirmation = jump < -1 || jump > Constants.maxStepForward * 2
        if needsConfirmation {
            if candidatePosition == matchIndex {
                candidateHits += 1
            } else {
                candidatePosition = matchIndex
                candidateHits = 1
            }
            if candidateHits < Constants.confirmationsRequired {
                return nil
            }
        }

        currentPosition = matchIndex
        consecutiveMisses = 0
        resetCandidate()
        return matchIndex
    }

    private struct PhraseMatch {
        let endIndex: Int
        let score: Double
    }

    private func matchPhrase(spokenWords: [String], startingNear position: Int) -> PhraseMatch? {
        let windowStart = max(0, position - Constants.searchWindowBack)
        let windowEnd = min(scriptWords.count - 1, position + Constants.searchWindowAhead)
        guard windowStart <= windowEnd else { return nil }
        guard spokenWords.count >= 2 else { return nil }

        let lastFew = Array(spokenWords.suffix(min(4, spokenWords.count)))
        guard windowEnd - windowStart + 1 >= lastFew.count else { return nil }

        var bestMatch: PhraseMatch?

        for startIdx in windowStart...(windowEnd - lastFew.count + 1) {
            var totalScore: Double = 0
            var comparisons = 0
            for (offset, spoken) in lastFew.enumerated() {
                let scriptIdx = startIdx + offset
                guard scriptIdx < scriptWords.count else { break }
                totalScore += StringSimilarity.normalizedSimilarity(spoken, scriptWords[scriptIdx].normalized)
                comparisons += 1
            }
            guard comparisons > 0 else { continue }
            let avgScore = totalScore / Double(comparisons)
            let endIdx = min(startIdx + comparisons - 1, scriptWords.count - 1)

            // Forward bias: slightly prefer matches that advance naturally
            let offset = endIdx - position
            var adjustedScore = avgScore
            if offset >= 0 && offset <= Constants.maxStepForward {
                adjustedScore += 0.02
            }

            if adjustedScore > (bestMatch?.score ?? 0) {
                bestMatch = PhraseMatch(endIndex: endIdx, score: adjustedScore)
            }
        }

        return bestMatch
    }

    func reset() {
        currentPosition = 0
        consecutiveMisses = 0
        resetCandidate()
    }

    private func resetCandidate() {
        candidatePosition = nil
        candidateHits = 0
    }
}
