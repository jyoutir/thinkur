import Foundation

struct PhraseMatch {
    let range: Range<String.Index>
    let matchedText: String
    let rule: ReplacementRule
}

struct PhraseMatcher {
    /// Find all matches for a list of replacement rules in the given text.
    /// Returns matches sorted by position (earliest first).
    static func findMatches(in text: String, rules: [ReplacementRule]) -> [PhraseMatch] {
        var matches: [PhraseMatch] = []

        for rule in rules {
            if rule.isRegex {
                guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }
                let nsRange = NSRange(text.startIndex..., in: text)
                for match in regex.matches(in: text, range: nsRange) {
                    guard let range = Range(match.range, in: text) else { continue }
                    matches.append(PhraseMatch(
                        range: range,
                        matchedText: String(text[range]),
                        rule: rule
                    ))
                }
            } else {
                let escaped = NSRegularExpression.escapedPattern(for: rule.pattern)
                let pattern = #"\b"# + escaped + #"\b"#
                guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
                let nsRange = NSRange(text.startIndex..., in: text)
                for match in regex.matches(in: text, range: nsRange) {
                    guard let range = Range(match.range, in: text) else { continue }
                    matches.append(PhraseMatch(
                        range: range,
                        matchedText: String(text[range]),
                        rule: rule
                    ))
                }
            }
        }

        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Find the first match in text from a list of rules.
    static func findFirst(in text: String, rules: [ReplacementRule]) -> PhraseMatch? {
        findMatches(in: text, rules: rules).first
    }

    /// Apply all replacement rules to text, longest-pattern-first.
    /// Returns the result text and all corrections made.
    static func applyReplacements(
        to text: String,
        rules: [ReplacementRule],
        processorName: String
    ) -> (text: String, corrections: [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        // Rules should be pre-sorted longest-first by caller
        for rule in rules {
            let (newText, mutations) = rule.isRegex
                ? TextMutator.replaceAll(in: result, pattern: rule.pattern, replacement: rule.replacement)
                : TextMutator.replaceLiteral(in: result, phrase: rule.pattern, replacement: rule.replacement)

            if !mutations.isEmpty {
                for mutation in mutations {
                    corrections.append(CorrectionEntry(
                        processorName: processorName,
                        ruleName: rule.category,
                        originalFragment: mutation.original,
                        replacement: rule.replacement,
                        confidence: rule.confidence
                    ))
                }
                result = newText
            }
        }

        return (result, corrections)
    }
}
