import Foundation
import NaturalLanguage

struct CapitalizationProcessor: TextProcessor {
    let name = "Capitalization"

    func process(_ text: String, context: ProcessingContext) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        // Capitalize sentence starts (after . ! ? and at beginning)
        result = capitalizeSentenceStarts(result)

        // Capitalize standalone "i"
        result = capitalizeI(result)

        // Capitalize proper nouns using NLTagger
        result = capitalizeProperNouns(result)

        return result
    }

    private func capitalizeSentenceStarts(_ text: String) -> String {
        var chars = Array(text)
        var capitalizeNext = true

        for i in 0..<chars.count {
            if capitalizeNext && chars[i].isLetter {
                chars[i] = Character(chars[i].uppercased())
                capitalizeNext = false
            } else if chars[i] == "." || chars[i] == "!" || chars[i] == "?" || chars[i] == "\n" {
                capitalizeNext = true
            }
        }

        return String(chars)
    }

    private func capitalizeI(_ text: String) -> String {
        // Replace standalone lowercase "i" with "I"
        guard let regex = try? NSRegularExpression(pattern: #"(?<=\s|^)i(?=\s|'|$|[.,!?;:])"#, options: []) else {
            return text
        }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "I"
        )
    }

    private func capitalizeProperNouns(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var result = text
        var replacements: [(Range<String.Index>, String)] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(text[range])
                if word.first?.isLowercase == true {
                    let capitalized = word.prefix(1).uppercased() + word.dropFirst()
                    replacements.append((range, capitalized))
                }
            }
            return true
        }

        // Apply in reverse to preserve indices
        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }

        return result
    }
}
