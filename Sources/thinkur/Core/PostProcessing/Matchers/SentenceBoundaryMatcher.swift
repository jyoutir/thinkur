import Foundation

struct SentenceBoundaryMatcher {
    /// Find likely sentence boundary positions in text when word timings are unavailable.
    /// Returns indices where a new sentence likely begins (i.e., positions of the first character
    /// of the word that starts a new sentence).
    static func findBoundaries(in text: String) -> [String.Index] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count >= 4 else { return [] }

        var boundaries: [String.Index] = []

        for i in 1..<words.count {
            let word = String(words[i])
            let wordLower = word.lowercased()
            let prevWord = String(words[i - 1]).lowercased().trimmingCharacters(in: .punctuationCharacters)
            let wordsBefore = i

            // Rule 1: Subject pronoun after lowercase word (likely starts new sentence)
            // "...word I/he/she/we/they ..." but NOT after conjunctions/prepositions
            if SentenceBoundaryRules.subjectPronouns.contains(wordLower) && wordsBefore >= 3 {
                if !SentenceBoundaryRules.joiningWords.contains(prevWord) &&
                   !SentenceBoundaryRules.incompleteEnders.contains(prevWord) {
                    boundaries.append(words[i].startIndex)
                    continue
                }
            }

            // Rule 2: Question opener after statement content
            if SentenceBoundaryRules.questionOpeners.contains(wordLower) && wordsBefore >= 3 {
                if !SentenceBoundaryRules.joiningWords.contains(prevWord) &&
                   !SentenceBoundaryRules.incompleteEnders.contains(prevWord) {
                    boundaries.append(words[i].startIndex)
                    continue
                }
            }

            // Rule 3: Discourse markers after sufficient prior content
            if SentenceBoundaryRules.discourseMarkers.contains(wordLower) && wordsBefore >= 4 {
                if !SentenceBoundaryRules.joiningWords.contains(prevWord) {
                    boundaries.append(words[i].startIndex)
                    continue
                }
            }

            // Rule 4: Contraction restarters after a complete-looking clause
            if SentenceBoundaryRules.contractionRestarters.contains(wordLower) && wordsBefore >= 3 {
                if !SentenceBoundaryRules.joiningWords.contains(prevWord) &&
                   !SentenceBoundaryRules.incompleteEnders.contains(prevWord) {
                    boundaries.append(words[i].startIndex)
                    continue
                }
            }
        }

        return boundaries
    }
}
