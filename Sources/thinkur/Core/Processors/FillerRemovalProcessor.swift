import Foundation
import NaturalLanguage

struct FillerRemovalProcessor: TextProcessor {
    let name = "FillerRemoval"

    private static let simpleFillers: Set<String> = [
        "um", "uh", "uhh", "umm", "hmm", "hm",
        "er", "erm", "ah", "ahh",
        "you know", "i guess", "sort of", "kind of",
    ]

    func process(_ text: String, context: ProcessingContext) -> String {
        var result = text

        // Remove multi-word fillers first
        for filler in Self.simpleFillers where filler.contains(" ") {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Process word by word for single-word fillers and "like" disambiguation
        let words = result.split(separator: " ", omittingEmptySubsequences: true)
        var cleaned: [String] = []

        for (i, word) in words.enumerated() {
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

            if Self.simpleFillers.contains(lower) && !lower.contains(" ") {
                continue
            }

            if lower == "like" && isFillerLike(words: words, index: i) {
                continue
            }

            cleaned.append(String(word))
        }

        result = cleaned.joined(separator: " ")
        return normalizeWhitespace(result)
    }

    private func isFillerLike(words: [Substring], index: Int) -> Bool {
        // "like" at sentence start or after a pause word is likely filler
        if index == 0 { return true }

        let prevWord = words[index - 1].lowercased().trimmingCharacters(in: .punctuationCharacters)
        let fillerPreceders: Set<String> = ["and", "but", "so", "was", "just", "it's", "its", "yeah", "oh", "well"]
        if fillerPreceders.contains(prevWord) { return true }

        // Use NLTagger to check if "like" is used as a verb/preposition (keep) vs filler (remove)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        let sentence = words.joined(separator: " ")
        tagger.string = sentence

        // Find the position of this "like" in the joined string
        var charOffset = 0
        for j in 0..<index {
            charOffset += words[j].count + 1
        }
        let targetIndex = sentence.index(sentence.startIndex, offsetBy: charOffset)
        let targetRange = targetIndex..<sentence.index(targetIndex, offsetBy: 4)

        if let tag = tagger.tag(at: targetIndex, unit: .word, scheme: .lexicalClass).0 {
            // If tagged as verb or preposition, keep it
            if tag == .verb || tag == .preposition {
                return false
            }
            // Adverb/interjection/other → likely filler
            let _ = targetRange
            return true
        }

        return false
    }
}
