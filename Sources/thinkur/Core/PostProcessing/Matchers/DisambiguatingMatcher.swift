import Foundation

struct DisambiguatingMatcher {
    /// Check if a word match should be kept (NOT replaced) by testing against keep-patterns.
    /// Returns true if any keep-pattern matches around the word in context.
    static func shouldKeep(word: String, in text: String, keepPatterns: [String]) -> Bool {
        for pattern in keepPatterns {
            guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: nsRange) != nil {
                return true
            }
        }
        return false
    }

    /// Check if a word match should be removed by testing against remove-patterns.
    /// Returns true if any remove-pattern matches.
    static func shouldRemove(word: String, in text: String, removePatterns: [String]) -> Bool {
        for pattern in removePatterns {
            guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: nsRange) != nil {
                return true
            }
        }
        return false
    }

    /// Apply a DisambiguationRule: check keep-patterns first, then remove-patterns.
    /// Returns true if the word should be removed (is filler/punctuation, not meaningful).
    static func shouldRemoveWord(rule: DisambiguationRule, in text: String) -> Bool {
        // If any keep-pattern matches, the word is meaningful — don't remove
        if shouldKeep(word: rule.word, in: text, keepPatterns: rule.keepPatterns) {
            return false
        }

        // If remove-patterns exist and match, remove the word
        if !rule.removePatterns.isEmpty {
            return shouldRemove(word: rule.word, in: text, removePatterns: rule.removePatterns)
        }

        // No remove-patterns defined — default to not removing
        return false
    }

    /// Check if any pattern in a list matches the given text.
    static func anyPatternMatches(_ patterns: [String], in text: String) -> Bool {
        for pattern in patterns {
            guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: nsRange) != nil {
                return true
            }
        }
        return false
    }
}
