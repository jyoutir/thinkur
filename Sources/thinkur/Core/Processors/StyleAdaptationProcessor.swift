import Foundation

struct StyleAdaptationProcessor: TextProcessor {
    let name = "StyleAdaptation"

    func process(_ text: String, context: ProcessingContext) -> String {
        guard !text.isEmpty else { return text }

        switch context.appStyle {
        case .casual:
            return applyCasualStyle(text)
        case .formal:
            return applyFormalStyle(text)
        case .code:
            return text // Minimal changes for code contexts
        case .standard:
            return text
        }
    }

    private func applyCasualStyle(_ text: String) -> String {
        var result = text

        // Strip trailing period from single sentences
        if !result.contains(". ") && result.hasSuffix(".") {
            result = String(result.dropLast())
        }

        // Lowercase first character for casual feel (unless it's "I" or a proper noun starting the text)
        if let first = result.first, first.isUppercase && result.count > 1 {
            let secondIndex = result.index(after: result.startIndex)
            let second = result[secondIndex]
            // Keep uppercase if followed by lowercase (proper noun) or if it's "I"
            if String(first) == "I" && (second == " " || second == "'" || secondIndex == result.endIndex) {
                // Keep "I" capitalized
            } else if second.isUppercase {
                // Acronym — keep as-is
            } else {
                result = first.lowercased() + result.dropFirst()
            }
        }

        return result
    }

    private func applyFormalStyle(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)

        // Ensure trailing punctuation
        if let last = result.last, !last.isPunctuation {
            result += "."
        }

        return result
    }
}
