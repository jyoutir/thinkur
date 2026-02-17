import Foundation

struct PausePunctuationProcessor: TextProcessor {
    let name = "PausePunctuation"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        let timings = context.wordTimings
        guard timings.count >= 2 else { return ProcessorResult(text: text) }

        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard words.count >= 2 else { return ProcessorResult(text: text) }

        let count = min(words.count, timings.count)
        let thresholds = WordTimingAnalyzer.adaptiveThresholds(from: timings)
        var corrections: [CorrectionEntry] = []

        // Phase 1: Insert punctuation based on timing gaps
        var insertions: [(index: Int, punctuation: String, confidence: Float)] = []

        for i in 0..<(count - 1) {
            let gap = timings[i + 1].start - timings[i].end

            // Skip if word already ends with punctuation
            if let lastChar = words[i].last,
               ".?!,:;".contains(lastChar) {
                continue
            }

            let currentLower = words[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
            let nextLower = (i + 1 < words.count) ? words[i + 1].lowercased() : ""

            if gap >= thresholds.sentenceBreak {
                // Don't insert period after incomplete enders
                if PausePunctuationRules.incompleteEnders.contains(currentLower) {
                    continue
                }

                // Don't insert period before continuation words
                if PausePunctuationRules.continuationWords.contains(nextLower) {
                    // Downgrade to comma instead
                    if !PausePunctuationRules.noCommaAfter.contains(currentLower) {
                        insertions.append((index: i, punctuation: ",", confidence: PausePunctuationRules.clauseConfidence))
                    }
                    continue
                }

                let confidence = gap >= thresholds.sentenceBreak * 3.0
                    ? PausePunctuationRules.highGapConfidence
                    : PausePunctuationRules.sentenceConfidence
                insertions.append((index: i, punctuation: ".", confidence: confidence))
            } else if gap >= thresholds.clauseBreak {
                // Don't insert comma after certain words
                if PausePunctuationRules.noCommaAfter.contains(currentLower) {
                    continue
                }
                insertions.append((index: i, punctuation: ",", confidence: PausePunctuationRules.clauseConfidence))
            }
        }

        // Apply insertions in reverse order
        for insertion in insertions.reversed() {
            if insertion.index < words.count {
                corrections.append(CorrectionEntry(
                    processorName: name,
                    ruleName: "pause_\(insertion.punctuation == "." ? "period" : "comma")",
                    originalFragment: words[insertion.index],
                    replacement: words[insertion.index] + insertion.punctuation,
                    confidence: insertion.confidence
                ))
                words[insertion.index] += insertion.punctuation
            }
        }

        // Phase 2: Detect questions
        var result = words.joined(separator: " ")
        result = markQuestions(result, corrections: &corrections)

        // Phase 3: Detect exclamations
        result = markExclamations(result, corrections: &corrections)

        // Phase 4: Detect tag questions
        result = markTagQuestions(result, corrections: &corrections)

        // Phase 5: Clean up double punctuation
        result = cleanDoublePunctuation(result)

        return ProcessorResult(text: result, corrections: corrections)
    }

    // MARK: - Question Detection

    private func markQuestions(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        let sentences = text.components(separatedBy: ".")
        var rebuilt: [String] = []

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip if already has terminal punctuation
            if let last = trimmed.last, "?!".contains(last) {
                rebuilt.append(trimmed)
                continue
            }

            let firstWord = trimmed.split(separator: " ").first?.lowercased() ?? ""
            if PausePunctuationRules.questionStarters.contains(firstWord) {
                corrections.append(CorrectionEntry(
                    processorName: name,
                    ruleName: "question",
                    originalFragment: trimmed + ".",
                    replacement: trimmed + "?",
                    confidence: PausePunctuationRules.questionConfidence
                ))
                rebuilt.append(trimmed + "?")
            } else {
                rebuilt.append(trimmed + ".")
            }
        }

        var result = rebuilt.joined(separator: " ")
        // Clean up trailing period if text didn't originally end with one
        if !text.hasSuffix(".") && result.hasSuffix(".") {
            result = String(result.dropLast())
        }
        return result
    }

    // MARK: - Exclamation Detection

    private func markExclamations(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        var result = text

        // Check for exclamatory multi-word starters
        for phrase in PausePunctuationRules.exclamatoryMultiWord {
            guard let regex = RegexCache.shared.regex(
                for: #"(?i)(?:^|(?<=[.!?]\s*))"# + NSRegularExpression.escapedPattern(for: phrase) + #"[^.!?]*[.]"#
            ) else { continue }

            let nsRange = NSRange(result.startIndex..., in: result)
            if let match = regex.firstMatch(in: result, range: nsRange),
               let range = Range(match.range, in: result) {
                let sentence = String(result[range])
                let wordCount = sentence.split(separator: " ").count
                if wordCount <= PausePunctuationRules.maxExclamationWords {
                    let replaced = String(sentence.dropLast()) + "!"
                    result.replaceSubrange(range, with: replaced)
                    corrections.append(CorrectionEntry(
                        processorName: name,
                        ruleName: "exclamation",
                        originalFragment: sentence,
                        replacement: replaced,
                        confidence: PausePunctuationRules.exclamationConfidence
                    ))
                }
            }
        }

        // Check for single-word exclamatory starters
        for starter in PausePunctuationRules.exclamatoryStarters {
            let pattern = #"(?i)(?:^|(?<=[.!?]\s*))"# + NSRegularExpression.escapedPattern(for: starter) + #"\b[^.!?]*[.]"#
            guard let regex = RegexCache.shared.regex(for: pattern) else { continue }

            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange)
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let sentence = String(result[range])
                let wordCount = sentence.split(separator: " ").count
                if wordCount <= PausePunctuationRules.maxExclamationWords {
                    let replaced = String(sentence.dropLast()) + "!"
                    result.replaceSubrange(range, with: replaced)
                    corrections.append(CorrectionEntry(
                        processorName: name,
                        ruleName: "exclamation",
                        originalFragment: sentence,
                        replacement: replaced,
                        confidence: PausePunctuationRules.exclamationConfidence
                    ))
                }
            }
        }

        return result
    }

    // MARK: - Tag Question Detection

    private func markTagQuestions(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        guard let regex = RegexCache.shared.regex(for: PausePunctuationRules.tagQuestionPattern) else {
            return text
        }

        var result = text
        let nsRange = NSRange(result.startIndex..., in: result)
        if let match = regex.firstMatch(in: result, range: nsRange),
           let range = Range(match.range, in: result) {
            let matched = String(result[range])
            let replaced = String(matched.dropLast()) + "?"
            result.replaceSubrange(range, with: replaced)
            corrections.append(CorrectionEntry(
                processorName: name,
                ruleName: "tag_question",
                originalFragment: matched,
                replacement: replaced,
                confidence: PausePunctuationRules.tagQuestionConfidence
            ))
        }

        return result
    }

    // MARK: - Double Punctuation Cleanup

    private func cleanDoublePunctuation(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in PausePunctuationRules.doublePunctuationPatterns {
            let (newText, _) = TextMutator.replaceAll(in: result, pattern: pattern, replacement: replacement)
            result = newText
        }
        return result
    }
}
