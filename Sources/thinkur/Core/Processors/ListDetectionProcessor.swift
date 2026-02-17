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

        // Determine list type from markers
        let category = markers.first?.category ?? "bullet"
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

        // Add any text before the first marker
        let beforeFirst = String(text[text.startIndex..<markers[0].range.lowerBound]).trimmingCharacters(in: .whitespaces)
        if !beforeFirst.isEmpty {
            result.append(beforeFirst)
        }

        for (i, item) in items.enumerated() {
            let prefix: String
            switch category {
            case "numbered":
                prefix = "\(i + 1). "
            case "ordinal":
                prefix = "\(i + 1). "
            default:
                prefix = ListDetectionRules.defaultBulletCharacter
            }

            corrections.append(CorrectionEntry(
                processorName: name,
                ruleName: "list_\(category)",
                originalFragment: item.marker.markerText,
                replacement: prefix,
                confidence: 0.85
            ))

            result.append(prefix + item.content)
        }

        return ProcessorResult(
            text: result.joined(separator: "\n"),
            corrections: corrections
        )
    }
}
