import Foundation

struct SelfCorrectionProcessor: TextProcessor {
    let name = "SelfCorrection"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }

        var result = text
        var allCorrections: [CorrectionEntry] = []

        // Phase 1: Explicit corrections (multi-pass, rightmost first)
        for _ in 0..<SelfCorrectionRules.maxCorrectionIterations {
            let (newText, correction) = processExplicitCorrection(result)
            if let correction {
                allCorrections.append(correction)
                result = newText
            } else {
                break
            }
        }

        // Phase 2: Remove stutters (repeated words like "the the")
        let (deduped, removedCount) = RepeatedNgramMatcher.removeStutters(in: result)
        if removedCount > 0 {
            allCorrections.append(CorrectionEntry(
                processorName: name,
                ruleName: "repeated_words",
                originalFragment: result,
                replacement: deduped,
                confidence: 0.95
            ))
            result = deduped
        }

        return ProcessorResult(
            text: result.trimmingCharacters(in: .whitespaces),
            corrections: allCorrections
        )
    }

    // MARK: - Explicit Correction Processing

    private func processExplicitCorrection(_ text: String) -> (String, CorrectionEntry?) {
        let lower = text.lowercased()

        // Check full reset patterns first (remove ALL preceding text)
        if let regex = RegexCache.shared.regex(for: SelfCorrectionRules.fullResetPattern),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range, in: lower) {
            let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
            let afterPhrase = text[originalRange.upperBound...]
            let keepText = String(afterPhrase.drop(while: { $0 == " " || $0 == "," }))
            let correction = CorrectionEntry(
                processorName: name,
                ruleName: "full_reset",
                originalFragment: String(text[text.startIndex..<originalRange.upperBound]),
                replacement: "",
                confidence: 1.0
            )
            return (keepText, correction)
        }

        // Check scope variations
        if let result = processScopeVariation(text, lower: lower) {
            return result
        }

        // Find the rightmost correction phrase.
        // Check explicit phrases first (high + medium confidence),
        // then contextual only if no explicit match found.
        var bestMatch: (range: Range<String.Index>, rule: ReplacementRule)?

        for rule in SelfCorrectionRules.allExplicitPhrases {
            if let match = findRightmostMatch(for: rule, in: lower) {
                if bestMatch == nil || match.lowerBound > bestMatch!.range.lowerBound {
                    bestMatch = (match, rule)
                }
            }
        }

        // Only check contextual phrases if no explicit match was found
        if bestMatch == nil {
            for rule in SelfCorrectionRules.contextualPhrases {
                if let match = findRightmostMatch(for: rule, in: lower) {
                    if bestMatch == nil || match.lowerBound > bestMatch!.range.lowerBound {
                        bestMatch = (match, rule)
                    }
                }
            }
        }

        guard let (matchRange, rule) = bestMatch else { return (text, nil) }

        // Check disambiguation for contextual phrases
        if rule.category == "contextual" {
            if !shouldTreatAsCorrection(rule.pattern, in: text) {
                return (text, nil)
            }
        }

        // Check disambiguation for "never mind" (literal use vs correction)
        if rule.pattern == "never mind" || rule.pattern == "nevermind" {
            if DisambiguatingMatcher.anyPatternMatches(SelfCorrectionRules.neverMindKeepPatterns, in: text) {
                return (text, nil)
            }
        }

        // Check for quoted speech context
        if isInQuotedSpeech(matchRange, in: lower) {
            return (text, nil)
        }

        // Convert range from lowercase to original text
        let lowerOffset = lower.distance(from: lower.startIndex, to: matchRange.lowerBound)
        let lowerEndOffset = lower.distance(from: lower.startIndex, to: matchRange.upperBound)
        let originalStart = text.index(text.startIndex, offsetBy: lowerOffset)
        let originalEnd = text.index(text.startIndex, offsetBy: lowerEndOffset)

        // Choose deletion scope based on confidence
        let clauseStart: String.Index
        let beforeCorrection = text[text.startIndex..<originalStart]

        if rule.confidence < 0.9 {
            // Medium/contextual: delete back to nearest structural boundary word
            clauseStart = findStructuralBoundary(in: beforeCorrection) ?? findSentenceBoundary(in: beforeCorrection, fullText: text) ?? text.startIndex
        } else {
            // High confidence: delete back to sentence boundary
            clauseStart = findSentenceBoundary(in: beforeCorrection, fullText: text) ?? text.startIndex
        }

        // Build result: text before clause + text after correction phrase
        let beforeClause = String(text[text.startIndex..<clauseStart])
        let afterPhrase = text[originalEnd...]
        let keepText = afterPhrase.drop(while: { $0 == " " || $0 == "," })

        let removedPortion = String(text[clauseStart..<originalEnd])
        let newText = beforeClause + keepText

        let correction = CorrectionEntry(
            processorName: name,
            ruleName: "explicit_\(rule.category)",
            originalFragment: removedPortion,
            replacement: "",
            confidence: rule.confidence
        )

        return (newText, correction)
    }

    // MARK: - Scope Variations

    private func processScopeVariation(_ text: String, lower: String) -> (String, CorrectionEntry?)? {
        // "remove last word"
        if let regex = RegexCache.shared.regex(for: SelfCorrectionRules.removeLastWordPattern),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range, in: lower) {
            let offset = lower.distance(from: lower.startIndex, to: range.lowerBound)
            let endOffset = lower.distance(from: lower.startIndex, to: range.upperBound)
            let origStart = text.index(text.startIndex, offsetBy: offset)
            let origEnd = text.index(text.startIndex, offsetBy: endOffset)

            var before = String(text[text.startIndex..<origStart]).trimmingCharacters(in: .whitespaces)
            let after = String(text[origEnd...]).trimmingCharacters(in: .whitespaces)

            // Remove the last word from 'before'
            if let lastSpace = before.lastIndex(of: " ") {
                let removedWord = String(before[before.index(after: lastSpace)...])
                before = String(before[before.startIndex...lastSpace]).trimmingCharacters(in: .whitespaces)
                let newText = after.isEmpty ? before : before + " " + after
                return (newText, CorrectionEntry(
                    processorName: name, ruleName: "remove_last_word",
                    originalFragment: removedWord, replacement: "", confidence: 1.0
                ))
            }
            // Only one word before the command
            let newText = after
            return (newText, CorrectionEntry(
                processorName: name, ruleName: "remove_last_word",
                originalFragment: before, replacement: "", confidence: 1.0
            ))
        }

        // "remove last sentence"
        if let regex = RegexCache.shared.regex(for: SelfCorrectionRules.removeLastSentencePattern),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range, in: lower) {
            let offset = lower.distance(from: lower.startIndex, to: range.lowerBound)
            let endOffset = lower.distance(from: lower.startIndex, to: range.upperBound)
            let origStart = text.index(text.startIndex, offsetBy: offset)
            let origEnd = text.index(text.startIndex, offsetBy: endOffset)

            let before = String(text[text.startIndex..<origStart])
            let after = String(text[origEnd...]).trimmingCharacters(in: .whitespaces)

            // Find last sentence boundary in 'before'
            let sentenceEnders: [Character] = [".", "!", "?"]
            if let lastBreak = before.lastIndex(where: { sentenceEnders.contains($0) }) {
                let removedSentence = String(before[before.index(after: lastBreak)...])
                let kept = String(before[before.startIndex...lastBreak])
                let newText = after.isEmpty ? kept.trimmingCharacters(in: .whitespaces) : kept.trimmingCharacters(in: .whitespaces) + " " + after
                return (newText, CorrectionEntry(
                    processorName: name, ruleName: "remove_last_sentence",
                    originalFragment: removedSentence, replacement: "", confidence: 1.0
                ))
            }
            // No prior sentence boundary — remove everything before the command
            return (after, CorrectionEntry(
                processorName: name, ruleName: "remove_last_sentence",
                originalFragment: before, replacement: "", confidence: 1.0
            ))
        }

        return nil
    }

    // MARK: - Pattern Matching Helper

    private func findRightmostMatch(for rule: ReplacementRule, in lower: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: rule.pattern)
        let pattern = #"(?<![a-zA-Z\-])"# + escaped + #"\b"#
        guard let regex = RegexCache.shared.regex(for: pattern) else { return nil }
        let nsRange = NSRange(lower.startIndex..., in: lower)
        let matches = regex.matches(in: lower, range: nsRange)
        guard let lastMatch = matches.last,
              let matchRange = Range(lastMatch.range, in: lower) else { return nil }
        return matchRange
    }

    // MARK: - Disambiguation

    private func shouldTreatAsCorrection(_ phrase: String, in text: String) -> Bool {
        switch phrase {
        case "i mean":
            return !DisambiguatingMatcher.anyPatternMatches(SelfCorrectionRules.iMeanKeepPatterns, in: text)
        case "actually":
            return !DisambiguatingMatcher.anyPatternMatches(SelfCorrectionRules.actuallyKeepPatterns, in: text)
        case "wait":
            return !DisambiguatingMatcher.anyPatternMatches(SelfCorrectionRules.waitKeepPatterns, in: text)
        case "no":
            return !DisambiguatingMatcher.anyPatternMatches(SelfCorrectionRules.noKeepPatterns, in: text)
        case "sorry":
            return !DisambiguatingMatcher.anyPatternMatches(SelfCorrectionRules.sorryKeepPatterns, in: text)
        default:
            return false
        }
    }

    /// Find the position just after the last structural boundary word.
    /// Returns the index of the space after the boundary word's content ends.
    private func findStructuralBoundary(in beforeCorrection: Substring) -> String.Index? {
        let words = beforeCorrection.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count >= 2 else { return nil }

        // Scan from right to left to find the nearest structural boundary word
        for i in stride(from: words.count - 1, through: 0, by: -1) {
            let word = words[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
            if SelfCorrectionRules.structuralBoundaryWords.contains(word) {
                // Return the index just after this boundary word — keep the boundary word
                // and delete from the word AFTER the boundary word
                if i + 1 < words.count {
                    return words[i + 1].startIndex
                }
                return nil
            }
        }
        return nil
    }

    /// Find the position just after the last sentence boundary.
    private func findSentenceBoundary(in beforeCorrection: Substring, fullText: String) -> String.Index? {
        let lastSentenceBreak = beforeCorrection.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" || $0 == "\n" })
        return lastSentenceBreak.map { fullText.index(after: $0) }
    }

    private func isInQuotedSpeech(_ range: Range<String.Index>, in text: String) -> Bool {
        guard let regex = RegexCache.shared.regex(for: SelfCorrectionRules.quotedSpeechPattern) else { return false }
        // Only treat as quoted speech if a speech verb appears immediately before the correction phrase
        // (within ~5 chars of whitespace/quotes, not separated by other words)
        let beforeStart = text.startIndex
        let beforeEnd = range.lowerBound
        guard beforeStart < beforeEnd else { return false }
        let beforeText = String(text[beforeStart..<beforeEnd])
        let nsRange = NSRange(beforeText.startIndex..., in: beforeText)
        let matches = regex.matches(in: beforeText, range: nsRange)
        guard let lastMatch = matches.last,
              let matchRange = Range(lastMatch.range, in: beforeText) else { return false }
        // The speech verb match must end within 5 characters of the correction phrase start
        let gapAfterVerb = beforeText.distance(from: matchRange.upperBound, to: beforeText.endIndex)
        return gapAfterVerb <= 5
    }
}
