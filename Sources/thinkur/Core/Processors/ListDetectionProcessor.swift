import Foundation

struct ListDetectionProcessor: TextProcessor {
    let name = "ListDetection"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }
        // Don't format lists in code context
        guard context.appStyle != .code else { return ProcessorResult(text: text) }

        let markers = ListMarkerMatcher.findMarkers(in: text)
        guard markers.count >= ListDetectionRules.minItemsForList else {
            return ProcessorResult(text: text)
        }

        // Check for narrative ordinals (disambiguation)
        if markers.allSatisfy({ $0.category == "ordinal" }) {
            if ListMarkerMatcher.isNarrativeOrdinal(in: text) {
                return ProcessorResult(text: text)
            }
        }

        // Bare number markers already pass sequential validation in the matcher
        // No additional disambiguation needed here

        // Determine list type from markers
        let category = markers.first?.category ?? "bullet"
        let isFormalOrStandard = context.appStyle == .formal || context.appStyle == .standard
        var corrections: [CorrectionEntry] = []

        // Build list items by splitting text at marker positions
        var items: [(marker: ListMarkerMatch, content: String)] = []
        for (i, marker) in markers.enumerated() {
            let contentStart = marker.range.upperBound
            let contentEnd = (i + 1 < markers.count) ? markers[i + 1].range.lowerBound : text.endIndex
            let content = String(text[contentStart..<contentEnd]).trimmingCharacters(in: .whitespaces)
            items.append((marker: marker, content: content))
        }

        // Format as list
        var result: [String] = []

        // Add any text before the first marker (preamble)
        let beforeFirst = String(text[text.startIndex..<markers[0].range.lowerBound]).trimmingCharacters(in: .whitespaces)
        if !beforeFirst.isEmpty {
            var preamble = beforeFirst
            // Add colon after preamble for formal/standard styles
            if isFormalOrStandard {
                // Strip trailing period if present, replace with colon
                if preamble.hasSuffix(".") {
                    preamble = String(preamble.dropLast())
                }
                if !preamble.hasSuffix(":") {
                    preamble += ":"
                }
            }
            result.append(preamble)
        }

        for (i, item) in items.enumerated() {
            let prefix: String
            switch category {
            case "numbered", "ordinal", "bare_number":
                prefix = "\(i + 1). "
            default:
                prefix = ListDetectionRules.defaultBulletCharacter
            }

            // Capitalize item content
            var content = item.content
            if let first = content.first, first.isLowercase {
                content = first.uppercased() + content.dropFirst()
            }

            // Add trailing period for formal/standard styles
            if isFormalOrStandard {
                let trimmed = content.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, let last = trimmed.last, !".!?".contains(last) {
                    content = trimmed + "."
                }
            }

            corrections.append(CorrectionEntry(
                processorName: name,
                ruleName: "list_\(category)",
                originalFragment: item.marker.markerText,
                replacement: prefix,
                confidence: 0.85
            ))

            result.append(prefix + content)
        }

        return ProcessorResult(
            text: result.joined(separator: "\n"),
            corrections: corrections
        )
    }
}
