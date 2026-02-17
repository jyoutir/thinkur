import Foundation

struct PausePunctuationProcessor: TextProcessor {
    let name = "PausePunctuation"

    private static let questionStarters: Set<String> = [
        "who", "what", "where", "when", "why", "how",
        "is", "are", "was", "were", "will", "would",
        "can", "could", "should", "do", "does", "did",
        "have", "has", "had", "shall", "may", "might",
    ]

    private static let periodPauseThreshold: Float = 0.8
    private static let commaPauseThreshold: Float = 0.4

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        let timings = context.wordTimings
        guard timings.count >= 2 else { return ProcessorResult(text: text) }

        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard words.count >= 2 else { return ProcessorResult(text: text) }

        // Match timings to words (best-effort: same count assumption)
        let count = min(words.count, timings.count)

        // Track insertions to avoid double-punctuating
        var insertions: [(index: Int, punctuation: String)] = []

        for i in 0..<(count - 1) {
            let gap = timings[i + 1].start - timings[i].end

            // Skip if word already ends with punctuation
            let lastChar = words[i].last
            if lastChar == "." || lastChar == "," || lastChar == "?" || lastChar == "!" || lastChar == ":" || lastChar == ";" {
                continue
            }

            if gap >= Self.periodPauseThreshold {
                // Check if next clause starts with a question word
                let nextWord = (i + 1 < words.count) ? words[i + 1].lowercased() : ""
                let isQuestion = Self.questionStarters.contains(nextWord)

                // Look ahead to see if this clause ends before another long pause
                if isQuestion {
                    // Find the end of the question clause and mark it
                    insertions.append((index: i, punctuation: "."))
                } else {
                    insertions.append((index: i, punctuation: "."))
                }
            } else if gap >= Self.commaPauseThreshold {
                insertions.append((index: i, punctuation: ","))
            }
        }

        // Apply insertions in reverse order to preserve indices
        for insertion in insertions.reversed() {
            if insertion.index < words.count {
                words[insertion.index] += insertion.punctuation
            }
        }

        // Detect questions: find clauses starting with question words and ending with periods, change to "?"
        var result = words.joined(separator: " ")
        result = markQuestions(result)

        return ProcessorResult(text: result)
    }

    private func markQuestions(_ text: String) -> String {
        // Split into sentences by period
        let sentences = text.components(separatedBy: ".")
        var rebuilt: [String] = []

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let firstWord = trimmed.split(separator: " ").first?.lowercased() ?? ""
            if Self.questionStarters.contains(firstWord) {
                rebuilt.append(trimmed + "?")
            } else {
                rebuilt.append(trimmed + ".")
            }
        }

        var result = rebuilt.joined(separator: " ")
        // Clean up trailing period if text didn't originally end with one
        if !text.hasSuffix(".") && result.hasSuffix(".") {
            result = String(result.dropLast())
        }
        return result
    }
}
