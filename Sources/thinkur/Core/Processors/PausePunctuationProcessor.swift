import Foundation

struct PausePunctuationProcessor: TextProcessor {
    let name = "PausePunctuation"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        let timings = context.wordTimings

        // If no timings available, use heuristic sentence splitting for standard/formal
        if timings.count < 2 {
            return processWithoutTimings(text, context: context)
        }

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

    // MARK: - No-Timings Fallback

    private func processWithoutTimings(_ text: String, context: ProcessingContext) -> ProcessorResult {
        // Only apply sentence splitting for standard/formal
        guard context.appStyle == .standard || context.appStyle == .formal else {
            return ProcessorResult(text: text)
        }

        // Check if text already has sentence-ending punctuation (e.g., from spoken punctuation)
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(". ") || trimmed.contains("? ") || trimmed.contains("! ") ||
           trimmed.contains(".\n") || trimmed.contains("?\n") || trimmed.contains("!\n") {
            // Already has internal punctuation, just do question detection
            var corrections: [CorrectionEntry] = []
            var result = detectFullTextQuestion(trimmed, corrections: &corrections)
            result = cleanDoublePunctuation(result)
            return ProcessorResult(text: result, corrections: corrections)
        }

        var corrections: [CorrectionEntry] = []
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)

        if boundaries.isEmpty {
            // Single sentence — just check if it's a question
            var result = detectFullTextQuestion(text, corrections: &corrections)
            result = cleanDoublePunctuation(result)
            return ProcessorResult(text: result, corrections: corrections)
        }

        // Split at boundaries, add periods and capitalize
        var result = text
        for boundary in boundaries.reversed() {
            // Find the last non-space character before the boundary
            var insertAt = boundary
            while insertAt > result.startIndex {
                let prev = result.index(before: insertAt)
                if result[prev] == " " {
                    insertAt = prev
                } else {
                    break
                }
            }

            // Don't add period if already has punctuation
            if insertAt > result.startIndex {
                let charBefore = result[result.index(before: insertAt)]
                if ".!?,;:".contains(charBefore) {
                    // Already has punctuation, just capitalize the next word
                    capitalizeAt(boundary, in: &result)
                    continue
                }
            }

            // Insert period before the space(s) and capitalize the next word
            result.insert(".", at: insertAt)
            // The boundary index shifted by 1 due to insertion
            let newBoundary = result.index(after: boundary)
            if newBoundary < result.endIndex {
                capitalizeAt(newBoundary, in: &result)
            }

            corrections.append(CorrectionEntry(
                processorName: name,
                ruleName: "sentence_boundary",
                originalFragment: "",
                replacement: ".",
                confidence: 0.75
            ))
        }

        // Check individual sentences for questions
        result = markQuestions(result, corrections: &corrections)
        result = detectFullTextQuestion(result, corrections: &corrections)
        result = cleanDoublePunctuation(result)

        return ProcessorResult(text: result, corrections: corrections)
    }

    private func capitalizeAt(_ index: String.Index, in text: inout String) {
        guard index < text.endIndex else { return }
        let char = text[index]
        if char.isLowercase {
            text.replaceSubrange(index...index, with: String(char).uppercased())
        }
    }

    // MARK: - Question Detection (full text, single sentence)

    private func detectFullTextQuestion(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return text }

        // If already ends with ? or !, don't modify
        if let last = trimmed.last, "?!".contains(last) { return text }

        let words = trimmed.split(separator: " ")
        var firstWord = words.first?.lowercased().trimmingCharacters(in: .punctuationCharacters) ?? ""

        // Skip greeting words to find the real question opener
        let greetings: Set<String> = ["hey", "hi", "hello", "ok", "okay"]
        if greetings.contains(firstWord), words.count > 1 {
            firstWord = String(words[1]).lowercased().trimmingCharacters(in: .punctuationCharacters)
        }

        if PausePunctuationRules.questionStarters.contains(firstWord) {
            // Check that it doesn't contain internal sentence punctuation
            // (which would mean it's multi-sentence)
            let inner = trimmed.dropFirst().dropLast()
            let hasInternalPeriods = inner.contains(". ") || inner.contains("? ") || inner.contains("! ")
            if !hasInternalPeriods {
                // Indirect questions: "I wonder if...", "I'm not sure whether..."
                let lower = trimmed.lowercased()
                if lower.hasPrefix("i wonder") || lower.hasPrefix("i'm not sure") ||
                   lower.hasPrefix("i am not sure") {
                    return text
                }

                var result = trimmed
                if result.hasSuffix(".") {
                    result = String(result.dropLast()) + "?"
                    corrections.append(CorrectionEntry(
                        processorName: name,
                        ruleName: "question_single",
                        originalFragment: ".",
                        replacement: "?",
                        confidence: PausePunctuationRules.questionConfidence
                    ))
                } else {
                    // No terminal punctuation yet — add question mark
                    result += "?"
                    corrections.append(CorrectionEntry(
                        processorName: name,
                        ruleName: "question_single",
                        originalFragment: "",
                        replacement: "?",
                        confidence: PausePunctuationRules.questionConfidence
                    ))
                }
                return result
            }
        }

        return text
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
            guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: replacement)
        }
        return result
    }
}
