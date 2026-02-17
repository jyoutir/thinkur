import Foundation

struct CasingCommandMatcher {
    /// Detect casing commands in text and apply the conversion.
    /// "camel case get user name" → "getUserName"
    /// "pascal case my class" → "MyClass"
    /// "snake case hello world" → "hello_world"
    static func applyCasingCommands(in text: String) -> (text: String, corrections: [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        for rule in CodeContextRules.casingCommands {
            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }

            // Find matches and process in reverse to preserve indices
            while true {
                let nsRange = NSRange(result.startIndex..., in: result)
                guard let match = regex.firstMatch(in: result, range: nsRange),
                      let range = Range(match.range, in: result) else { break }

                // Everything after the casing command keyword up to punctuation/end is the words to case
                let afterCommand = result[range.upperBound...]
                let wordsToCase = afterCommand.prefix(while: { !".!?\n;".contains($0) })
                let wordList = wordsToCase.split(separator: " ").map { $0.lowercased() }

                guard !wordList.isEmpty else {
                    result.replaceSubrange(range, with: "")
                    break
                }

                let casingType = rule.replacement
                let cased = applyCase(casingType, to: wordList)

                let fullRange = range.lowerBound..<result.index(range.upperBound, offsetBy: wordsToCase.count)
                let original = String(result[fullRange])

                corrections.append(CorrectionEntry(
                    processorName: "CodeContext", ruleName: "casing_\(casingType)",
                    originalFragment: original, replacement: cased, confidence: rule.confidence
                ))

                result.replaceSubrange(fullRange, with: cased)
            }
        }

        return (result, corrections)
    }

    private static func applyCase(_ type: String, to words: [String]) -> String {
        switch type {
        case "camelCase":
            guard let first = words.first else { return "" }
            return first + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        case "pascalCase":
            return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        case "snakeCase":
            return words.joined(separator: "_")
        case "screamingSnakeCase":
            return words.map { $0.uppercased() }.joined(separator: "_")
        case "kebabCase":
            return words.joined(separator: "-")
        case "dotCase":
            return words.joined(separator: ".")
        default:
            return words.joined(separator: " ")
        }
    }
}
