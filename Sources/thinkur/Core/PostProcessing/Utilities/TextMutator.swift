import Foundation

struct TextMutation {
    let range: Range<String.Index>
    let original: String
    let replacement: String
}

struct TextMutator {
    static func replaceAll(
        in text: String,
        pattern: String,
        replacement: String,
        options: NSRegularExpression.Options = .caseInsensitive
    ) -> (result: String, mutations: [TextMutation]) {
        guard let regex = RegexCache.shared.regex(for: pattern, options: options) else {
            return (text, [])
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        guard !matches.isEmpty else { return (text, []) }

        var mutations: [TextMutation] = []
        var result = text

        // Process matches in reverse to maintain correct indices
        // Append mutations and reverse at end to avoid O(n²) insert-at-0 operations
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let original = String(result[range])
            mutations.append(TextMutation(range: range, original: original, replacement: replacement))
            result.replaceSubrange(range, with: replacement)
        }

        return (result, mutations.reversed())
    }

    static func replaceLiteral(
        in text: String,
        phrase: String,
        replacement: String
    ) -> (result: String, mutations: [TextMutation]) {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "\\b\(escaped)\\b"
        return replaceAll(in: text, pattern: pattern, replacement: replacement)
    }

    /// Apply regex replacements with a custom replacer function.
    /// Processes matches in reverse order to preserve indices.
    /// Returns the mutated text and list of mutations in forward order.
    static func applyReplacements(
        in text: String,
        matches: [NSTextCheckingResult],
        replacer: (NSTextCheckingResult, String) -> String
    ) -> (result: String, mutations: [TextMutation]) {
        var result = text
        var mutations: [TextMutation] = []

        // Process matches in reverse to maintain correct indices
        // Append mutations and reverse at end to avoid O(n²) insert-at-0 operations
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let original = String(result[range])
            let replacement = replacer(match, original)
            mutations.append(TextMutation(range: range, original: original, replacement: replacement))
            result.replaceSubrange(range, with: replacement)
        }

        return (result, mutations.reversed())
    }
}
