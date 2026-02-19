import Foundation

struct SpokenPunctuationProcessor: TextProcessor {
    let name = "SpokenPunctuation"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }

        var result = text
        var allCorrections: [CorrectionEntry] = []

        // Process rules in order: formatting commands, sentence-ending, mid-sentence,
        // paired delimiters, special characters — all pre-sorted longest-first in allRules
        for rule in SpokenPunctuationRules.allRules {
            // Disambiguation checks for ambiguous words
            if shouldSkipRule(rule, in: result) { continue }

            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange)

            guard !matches.isEmpty else { continue }

            // Apply replacements in reverse order to preserve indices
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let original = String(result[range])

                allCorrections.append(CorrectionEntry(
                    processorName: name,
                    ruleName: rule.category,
                    originalFragment: original,
                    replacement: rule.replacement,
                    confidence: rule.confidence
                ))

                result.replaceSubrange(range, with: rule.replacement)
            }
        }

        result = cleanPunctuationSpacing(result)
        // Remove space after # and @ when they prefix the next word
        result = result.replacingOccurrences(of: "# ", with: "#")
        result = result.replacingOccurrences(of: "@ ", with: "@")
        // Convert "dot" to "." in email/URL address contexts: "john@example dot com" → "john@example.com"
        if let regex = RegexCache.shared.regex(for: #"(?i)(@\w+(?:\.\w+)*)\s+dot\s+(\w+)"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: "$1.$2")
        }
        // Remove spaces inside quotes: "  text  " → "text"
        if let regex = RegexCache.shared.regex(for: #""\s+([^"]+?)\s+""#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: #""$1""#)
        }
        // Attach @ to preceding word: "john @example" → "john@example"
        if let regex = RegexCache.shared.regex(for: #"(\w)\s+@(\w)"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: "$1@$2")
        }
        // Normalize spaces around paragraph breaks: "here \n\n next" → "here\n\nnext"
        if let regex = RegexCache.shared.regex(for: #"[ \t]*\n\n[ \t]*"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: "\n\n")
        }
        return ProcessorResult(
            text: normalizeWhitespace(result),
            corrections: allCorrections
        )
    }

    // MARK: - Disambiguation

    private func shouldSkipRule(_ rule: ReplacementRule, in text: String) -> Bool {
        // Check "period" disambiguation
        if rule.pattern.contains("\\bperiod\\b") {
            if DisambiguatingMatcher.anyPatternMatches(SpokenPunctuationRules.periodKeepPatterns, in: text) {
                return true
            }
        }

        // Check "colon" disambiguation
        if rule.pattern.contains("\\bcolon\\b") {
            if DisambiguatingMatcher.anyPatternMatches(SpokenPunctuationRules.colonKeepPatterns, in: text) {
                return true
            }
        }

        // Check "dash" disambiguation (verb usage: "need to dash to the store")
        if rule.pattern.contains("\\bdash\\b") && rule.category == "mid_sentence" {
            if DisambiguatingMatcher.anyPatternMatches(SpokenPunctuationRules.dashKeepPatterns, in: text) {
                return true
            }
        }

        return false
    }
}
