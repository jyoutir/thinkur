import Foundation

struct CodeContextProcessor: TextProcessor {
    let name = "CodeContext"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }
        // Only active in code context
        guard context.appStyle == .code else { return ProcessorResult(text: text) }

        var result = text
        var allCorrections: [CorrectionEntry] = []

        // Phase 1: Comment mode detection ("comment hello world" → "// hello world")
        let (afterComments, commentCorrections) = processComments(result)
        result = afterComments
        allCorrections.append(contentsOf: commentCorrections)

        // Phase 2: Casing commands ("camel case get user name" → "getUserName")
        let (afterCasing, casingCorrections) = CasingCommandMatcher.applyCasingCommands(in: result)
        result = afterCasing
        allCorrections.append(contentsOf: casingCorrections)

        // Phase 3: Operators ("equals" → "=", "less than" → "<")
        let (afterOps, opsCorrections) = OperatorMatcher.applyOperators(in: result)
        result = afterOps
        allCorrections.append(contentsOf: opsCorrections)

        // Phase 4: Property access ("user dot name" → "user.name")
        let (afterDot, dotCorrections) = processPropertyAccess(result)
        result = afterDot
        allCorrections.append(contentsOf: dotCorrections)

        return ProcessorResult(
            text: normalizeWhitespace(result),
            corrections: allCorrections
        )
    }

    // MARK: - Comment Processing

    private func processComments(_ text: String) -> (String, [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        for rule in CodeContextRules.commentModePatterns {
            guard let regex = RegexCache.shared.regex(for: rule.pattern) else { continue }

            let nsRange = NSRange(result.startIndex..., in: result)
            guard let match = regex.firstMatch(in: result, range: nsRange),
                  let range = Range(match.range, in: result) else { continue }

            let original = String(result[range])
            let keyword = original.trimmingCharacters(in: .whitespaces).lowercased()

            if rule.replacement == "annotation" {
                // Handle TODO/FIXME/etc: "todo fix the bug" → "// TODO: fix the bug"
                let annotationWord = keyword.trimmingCharacters(in: .punctuationCharacters)
                if let annotation = CodeContextRules.annotationKeywords[annotationWord] {
                    let afterMatch = String(result[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let replacement = "// \(annotation): \(afterMatch)"
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "comment_annotation",
                        originalFragment: String(result[range.lowerBound...]),
                        replacement: replacement, confidence: rule.confidence
                    ))
                    result = String(result[result.startIndex..<range.lowerBound]) + replacement
                    return (result, corrections)
                }
            } else {
                // Regular comment: "comment hello world" → "// hello world"
                let prefix = rule.replacement
                let afterMatch = String(result[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let replacement = prefix + afterMatch
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "comment",
                    originalFragment: String(result[range.lowerBound...]),
                    replacement: replacement, confidence: rule.confidence
                ))
                result = String(result[result.startIndex..<range.lowerBound]) + replacement
                return (result, corrections)
            }
        }

        return (result, corrections)
    }

    // MARK: - Property Access

    private func processPropertyAccess(_ text: String) -> (String, [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        guard let regex = RegexCache.shared.regex(for: CodeContextRules.propertyAccessPattern) else {
            return (result, corrections)
        }

        // Apply in reverse to preserve indices
        let nsRange = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, range: nsRange)

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  match.numberOfRanges >= 3,
                  let objRange = Range(match.range(at: 1), in: result),
                  let propRange = Range(match.range(at: 2), in: result) else { continue }

            let obj = String(result[objRange])
            let prop = String(result[propRange]).trimmingCharacters(in: .whitespaces)
            let original = String(result[fullRange])
            let replacement = "\(obj).\(prop)"

            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "property_access",
                originalFragment: original, replacement: replacement, confidence: 0.85
            ))
            result.replaceSubrange(fullRange, with: replacement)
        }

        return (result, corrections)
    }
}
