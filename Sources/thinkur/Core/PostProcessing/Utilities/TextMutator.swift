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

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let original = String(result[range])
            mutations.insert(TextMutation(range: range, original: original, replacement: replacement), at: 0)
            result.replaceSubrange(range, with: replacement)
        }

        return (result, mutations)
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
}
