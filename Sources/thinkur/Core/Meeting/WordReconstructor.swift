import FluidAudio

struct ReconstructedWord {
    let text: String
    let start: Double
    let end: Double
    let confidence: Float
}

/// Groups BPE sub-word tokens into whole words with timing spans.
/// BPE convention: word-initial tokens have a leading space (" Hello"),
/// continuation tokens don't ("fect" in "per"+"fect").
enum WordReconstructor {
    static func reconstruct(
        tokens: [TokenTiming],
        chunkStartTime: Double = 0
    ) -> [ReconstructedWord] {
        guard !tokens.isEmpty else { return [] }

        var words: [ReconstructedWord] = []
        var currentText = ""
        var currentStart: Double = 0
        var currentEnd: Double = 0
        var confidenceSum: Float = 0
        var tokenCount: Float = 0

        for (index, timing) in tokens.enumerated() {
            let token = timing.token
            let isWordStart = token.hasPrefix(" ") || index == 0

            if isWordStart && !currentText.isEmpty {
                // Flush accumulated word
                let trimmed = currentText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    words.append(ReconstructedWord(
                        text: trimmed,
                        start: currentStart,
                        end: currentEnd,
                        confidence: confidenceSum / tokenCount
                    ))
                }
                currentText = ""
                confidenceSum = 0
                tokenCount = 0
            }

            if currentText.isEmpty {
                currentStart = chunkStartTime + timing.startTime
            }
            currentText += token
            currentEnd = chunkStartTime + timing.endTime
            confidenceSum += timing.confidence
            tokenCount += 1
        }

        // Flush last word
        let trimmed = currentText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            words.append(ReconstructedWord(
                text: trimmed,
                start: currentStart,
                end: currentEnd,
                confidence: confidenceSum / tokenCount
            ))
        }

        return words
    }
}
