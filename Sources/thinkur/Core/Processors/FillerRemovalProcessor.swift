import Foundation
import NaturalLanguage

struct FillerRemovalProcessor: TextProcessor {
    let name = "FillerRemoval"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }

        var result = text
        var allCorrections: [CorrectionEntry] = []

        // Phase 1: Multi-word fillers (longest first — already sorted in Rules)
        let (afterMulti, multiCorrections) = PhraseMatcher.applyReplacements(
            to: result,
            rules: FillerRemovalRules.multiWordFillers,
            processorName: name
        )
        result = afterMulti
        allCorrections.append(contentsOf: multiCorrections)

        // Phase 2: Verbal tics
        let (afterTics, ticCorrections) = PhraseMatcher.applyReplacements(
            to: result,
            rules: FillerRemovalRules.verbalTics,
            processorName: name
        )
        result = afterTics
        allCorrections.append(contentsOf: ticCorrections)

        // Phase 3: Hesitation fillers + "like" disambiguation (word-by-word)
        // Must run BEFORE discourse markers so "um so" → "" (not "so")
        let (afterHesitations, hesitationCorrections) = removeHesitationsAndLike(result)
        result = afterHesitations
        allCorrections.append(contentsOf: hesitationCorrections)

        // Phase 4: Discourse markers with disambiguation
        let (afterDiscourse, discourseCorrections) = removeDiscourseMarkers(result)
        result = afterDiscourse
        allCorrections.append(contentsOf: discourseCorrections)

        return ProcessorResult(
            text: normalizeWhitespace(result),
            corrections: allCorrections
        )
    }

    // MARK: - Discourse Markers

    private func removeDiscourseMarkers(_ text: String) -> (String, [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        for marker in FillerRemovalRules.discourseMarkers {
            if marker.disambiguate {
                // Use full disambiguation rules for well/so/okay/right
                let disambiguationRule = disambiguationRuleFor(marker.word)
                if let rule = disambiguationRule {
                    // Apply all remove patterns, but skip if any keep pattern
                    // matches at the SAME position as the filler
                    for removePattern in rule.removePatterns {
                        let (newText, mutations) = removeWithLocalDisambiguation(
                            text: result, removePattern: removePattern,
                            keepPatterns: rule.keepPatterns, word: marker.word,
                            confidence: marker.confidence
                        )
                        if !mutations.isEmpty {
                            corrections.append(contentsOf: mutations)
                            result = newText
                        }
                    }
                }
            } else {
                // Non-disambiguated markers — remove anywhere as standalone word
                let escaped = NSRegularExpression.escapedPattern(for: marker.word)
                let pattern = #"(?i)(?:^|(?<=\s))"# + escaped + #"[,]?\s+"#
                let (newText, mutations) = TextMutator.replaceAll(in: result, pattern: pattern, replacement: "")
                if !mutations.isEmpty {
                    for mutation in mutations {
                        corrections.append(CorrectionEntry(
                            processorName: name,
                            ruleName: "discourse_\(marker.word)",
                            originalFragment: mutation.original,
                            replacement: "",
                            confidence: marker.confidence
                        ))
                    }
                    result = newText
                }
            }
        }

        return (result, corrections)
    }

    /// Remove a filler word only at positions where no keep pattern matches locally.
    private func removeWithLocalDisambiguation(
        text: String, removePattern: String, keepPatterns: [String],
        word: String, confidence: Float
    ) -> (String, [CorrectionEntry]) {
        guard let removeRegex = RegexCache.shared.regex(for: removePattern) else { return (text, []) }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = removeRegex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else { return (text, []) }

        var result = text
        var corrections: [CorrectionEntry] = []

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }

            // Check if any keep pattern overlaps this specific match position
            let matchStart = result.distance(from: result.startIndex, to: range.lowerBound)
            let matchEnd = result.distance(from: result.startIndex, to: range.upperBound)
            var keepThis = false

            for keepPattern in keepPatterns {
                guard let keepRegex = RegexCache.shared.regex(for: keepPattern) else { continue }
                let keepNSRange = NSRange(result.startIndex..., in: result)
                let keepMatches = keepRegex.matches(in: result, range: keepNSRange)
                for km in keepMatches {
                    // If the keep match overlaps with the remove match, preserve it
                    if km.range.location < matchEnd && (km.range.location + km.range.length) > matchStart {
                        keepThis = true
                        break
                    }
                }
                if keepThis { break }
            }

            if !keepThis {
                let original = String(result[range])
                corrections.insert(CorrectionEntry(
                    processorName: name,
                    ruleName: "discourse_\(word)",
                    originalFragment: original,
                    replacement: "",
                    confidence: confidence
                ), at: 0)
                result.replaceSubrange(range, with: "")
            }
        }

        return (result, corrections)
    }

    private func disambiguationRuleFor(_ word: String) -> DisambiguationRule? {
        switch word {
        case "well": return FillerRemovalRules.wellDisambiguation
        case "so": return FillerRemovalRules.soDisambiguation
        case "okay", "ok": return FillerRemovalRules.okayDisambiguation
        case "right": return FillerRemovalRules.rightDisambiguation
        default: return nil
        }
    }

    // MARK: - Hesitation Fillers + Like

    private func removeHesitationsAndLike(_ text: String) -> (String, [CorrectionEntry]) {
        let hesitationWords = Set(FillerRemovalRules.hesitationFillers.map { $0.pattern })
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        var cleaned: [String] = []
        var corrections: [CorrectionEntry] = []

        for (i, word) in words.enumerated() {
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

            // Check hesitation fillers
            if hesitationWords.contains(lower) {
                // Check exclamatory usage (ah/oh at clause start with comma)
                if (lower == "ah" || lower == "oh"),
                   let regex = RegexCache.shared.regex(for: FillerRemovalRules.exclamatoryPattern),
                   regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil,
                   i == 0 || words[i - 1].hasSuffix(".") || words[i - 1].hasSuffix("!") || words[i - 1].hasSuffix("?") {
                    cleaned.append(String(word))
                    continue
                }

                corrections.append(CorrectionEntry(
                    processorName: name,
                    ruleName: "hesitation_\(lower)",
                    originalFragment: String(word),
                    replacement: "",
                    confidence: 0.95
                ))
                continue
            }

            // Check "like" disambiguation
            if lower == "like" && isFillerLike(words: words, index: i, fullText: text) {
                corrections.append(CorrectionEntry(
                    processorName: name,
                    ruleName: "filler_like",
                    originalFragment: String(word),
                    replacement: "",
                    confidence: 0.7
                ))
                continue
            }

            cleaned.append(String(word))
        }

        return (cleaned.joined(separator: " "), corrections)
    }

    private func isFillerLike(words: [Substring], index: Int, fullText: String) -> Bool {
        // Check keep patterns first
        if DisambiguatingMatcher.anyPatternMatches(FillerRemovalRules.likeKeepPatterns, in: fullText) {
            // Crude check: is this "like" the one matched by a keep pattern?
            // For safety, if any keep pattern matches in the full text, preserve this "like"
            // unless we can confirm it's not the one being protected
            let sentence = words.joined(separator: " ")
            if DisambiguatingMatcher.anyPatternMatches(FillerRemovalRules.likeKeepPatterns, in: sentence) {
                return false
            }
        }

        // "like" at sentence start is likely filler
        if index == 0 { return true }

        // After a filler preceder word
        let prevWord = words[index - 1].lowercased().trimmingCharacters(in: .punctuationCharacters)
        if FillerRemovalRules.fillerPreceders.contains(prevWord) { return true }

        // Use NLTagger to check if "like" is a verb/preposition (keep) vs filler (remove)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        let sentence = words.joined(separator: " ")
        tagger.string = sentence

        var charOffset = 0
        for j in 0..<index {
            charOffset += words[j].count + 1
        }

        guard charOffset < sentence.count else { return false }
        let targetIndex = sentence.index(sentence.startIndex, offsetBy: charOffset)

        if let tag = tagger.tag(at: targetIndex, unit: .word, scheme: .lexicalClass).0 {
            if tag == .verb || tag == .preposition {
                return false
            }
            return true
        }

        return false
    }
}
