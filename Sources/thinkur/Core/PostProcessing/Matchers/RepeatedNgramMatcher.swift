import Foundation

struct RepeatedNgramMatch {
    let range: Range<String.Index>
    let repeatedText: String
    let count: Int
}

struct RepeatedNgramMatcher {
    /// Detect immediately repeated words (stutters): "the the dog" → "the dog"
    /// Excludes intentional repetitions like "very very" from the safelist.
    static func findRepeatedWords(
        in text: String,
        safelist: Set<String> = SelfCorrectionRules.intentionalRepetitions
    ) -> [(index: Int, word: String)] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var repeats: [(index: Int, word: String)] = []

        var i = 0
        while i < words.count - 1 {
            let current = words[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
            let next = words[i + 1].lowercased().trimmingCharacters(in: .punctuationCharacters)

            if current == next && !current.isEmpty && !safelist.contains(current) {
                repeats.append((index: i, word: current))
            }
            i += 1
        }

        return repeats
    }

    /// Remove immediately repeated words (stutters), preserving intentional repetitions.
    static func removeStutters(
        in text: String,
        safelist: Set<String> = SelfCorrectionRules.intentionalRepetitions
    ) -> (result: String, removedCount: Int) {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard words.count >= 2 else { return (text, 0) }

        var cleaned: [String] = [words[0]]
        var removedCount = 0

        for i in 1..<words.count {
            let prevClean = cleaned.last?.lowercased().trimmingCharacters(in: .punctuationCharacters) ?? ""
            let currentClean = words[i].lowercased().trimmingCharacters(in: .punctuationCharacters)

            if prevClean == currentClean && !currentClean.isEmpty && !safelist.contains(currentClean) {
                removedCount += 1
                continue
            }
            cleaned.append(words[i])
        }

        return (cleaned.joined(separator: " "), removedCount)
    }

    /// Detect repeated sentence starters: "I went I went to the store" → "I went to the store"
    /// Looks for 2-3 word n-grams that repeat at the start of what appears to be a restart.
    static func findRepeatedStarters(in text: String) -> [(firstStart: Int, secondStart: Int, length: Int)] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map {
            $0.lowercased().trimmingCharacters(in: .punctuationCharacters)
        }
        guard words.count >= 4 else { return [] }

        var results: [(firstStart: Int, secondStart: Int, length: Int)] = []

        // Check for 3-word, then 2-word repeated starters
        for ngramLen in stride(from: 3, through: 2, by: -1) {
            var i = 0
            while i <= words.count - ngramLen * 2 {
                let ngram = Array(words[i..<(i + ngramLen)])
                // Look for the same n-gram later
                for j in (i + ngramLen)..<(words.count - ngramLen + 1) {
                    let candidate = Array(words[j..<(j + ngramLen)])
                    if ngram == candidate {
                        results.append((firstStart: i, secondStart: j, length: ngramLen))
                        i = j + ngramLen
                        break
                    }
                }
                i += 1
            }
        }

        return results
    }
}
