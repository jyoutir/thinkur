import Foundation

struct ListMarkerMatch {
    let range: Range<String.Index>
    let markerText: String
    let itemNumber: Int?
    let category: String  // "numbered", "ordinal", "bullet", "continuation"
}

struct ListMarkerMatcher {
    /// Detect list markers in text and return matches with their positions.
    static func findMarkers(in text: String) -> [ListMarkerMatch] {
        let lower = text.lowercased()
        var matches: [ListMarkerMatch] = []

        // Check numbered markers: "number one", "item two", etc.
        for rule in ListDetectionRules.numberedMarkerPatterns {
            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }
            let nsRange = NSRange(lower.startIndex..., in: lower)
            for match in regex.matches(in: lower, range: nsRange) {
                guard let range = Range(match.range, in: lower) else { continue }
                let matched = String(lower[range])
                let words = matched.split(separator: " ")
                let numberWord = words.count >= 2 ? String(words[1]).trimmingCharacters(in: .punctuationCharacters) : ""
                let number = ListDetectionRules.numberWordToInt[numberWord] ?? Int(numberWord)
                let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
                matches.append(ListMarkerMatch(
                    range: originalRange, markerText: String(text[originalRange]),
                    itemNumber: number, category: "numbered"
                ))
            }
        }

        // Check ordinal markers: "firstly", "secondly", "first", "second"
        for rule in ListDetectionRules.ordinalMarkerPatterns {
            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }
            let nsRange = NSRange(lower.startIndex..., in: lower)
            for match in regex.matches(in: lower, range: nsRange) {
                guard let range = Range(match.range, in: lower) else { continue }
                let matched = String(lower[range]).trimmingCharacters(in: .whitespaces)
                let keyword = matched.trimmingCharacters(in: .punctuationCharacters).lowercased()
                let number = ListDetectionRules.numberWordToInt[keyword]
                let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
                matches.append(ListMarkerMatch(
                    range: originalRange, markerText: String(text[originalRange]),
                    itemNumber: number, category: "ordinal"
                ))
            }
        }

        // Check bullet markers: "bullet point", "new bullet"
        for rule in ListDetectionRules.bulletMarkerPatterns {
            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }
            let nsRange = NSRange(lower.startIndex..., in: lower)
            for match in regex.matches(in: lower, range: nsRange) {
                guard let range = Range(match.range, in: lower) else { continue }
                let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
                matches.append(ListMarkerMatch(
                    range: originalRange, markerText: String(text[originalRange]),
                    itemNumber: nil, category: "bullet"
                ))
            }
        }

        // Check bare number markers (only if no other markers found)
        if matches.isEmpty {
            let bareMatches = findBareNumberMarkers(in: text, lower: lower)
            matches.append(contentsOf: bareMatches)
        }

        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Detect bare number words/digits as list markers with sequential validation.
    private static func findBareNumberMarkers(in text: String, lower: String) -> [ListMarkerMatch] {
        // Check narrative disambiguation first
        if DisambiguatingMatcher.anyPatternMatches(ListDetectionRules.bareNumberNarrativePatterns, in: text) {
            return []
        }

        var candidates: [ListMarkerMatch] = []

        for rule in ListDetectionRules.bareNumberMarkerPatterns {
            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }
            let nsRange = NSRange(lower.startIndex..., in: lower)
            for match in regex.matches(in: lower, range: nsRange) {
                guard let range = Range(match.range, in: lower),
                      match.numberOfRanges > 1,
                      let numberRange = Range(match.range(at: 1), in: lower) else { continue }
                let numberStr = String(lower[numberRange])
                let number = ListDetectionRules.numberWordToInt[numberStr] ?? Int(numberStr)
                guard let number else { continue }
                let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
                candidates.append(ListMarkerMatch(
                    range: originalRange, markerText: String(text[originalRange]),
                    itemNumber: number, category: "bare_number"
                ))
            }
        }

        // Sequential validation: bare markers must form a sequential list (1,2,3 not 1,5,3)
        guard candidates.count >= ListDetectionRules.minItemsForList else { return [] }
        let sorted = candidates.sorted { ($0.itemNumber ?? 0) < ($1.itemNumber ?? 0) }
        for i in 0..<(sorted.count - 1) {
            let current = sorted[i].itemNumber ?? 0
            let next = sorted[i + 1].itemNumber ?? 0
            if next != current + 1 { return [] }
        }

        return candidates
    }

    /// Check if ordinal words are used as narrative (not list markers).
    static func isNarrativeOrdinal(in text: String) -> Bool {
        DisambiguatingMatcher.anyPatternMatches(ListDetectionRules.ordinalNarrativePatterns, in: text)
    }
}
