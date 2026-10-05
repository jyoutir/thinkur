import Foundation

struct ListDetectionProcessor: TextProcessor {
    let name = "ListDetection"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }
        // Don't format lists in code context
        guard context.appStyle != .code else { return ProcessorResult(text: text) }

        // Inferential number/ordinal sequences are ambiguous in ordinary dictation.
        // Only explicit list cues (numbered or bullet) should turn spoken text into a formatted list.
        // Filter to explicit markers before count check and splitting so ordinals or numbers
        // in item content (e.g. "bullet point call the third party") do not reject the list or split items.
        let allMarkers = ListMarkerMatcher.findMarkers(in: text)
        let markers = allMarkers.filter { $0.category == "numbered" || $0.category == "bullet" }
        guard markers.count >= ListDetectionRules.minItemsForList else {
            return ProcessorResult(text: text)
        }

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

        let baseNumber = markers.first(where: { $0.category == "numbered" })?.itemNumber ?? 1
        var numberedCount = 0

        for item in items {
            let prefix: String
            switch item.marker.category {
            case "numbered":
                let num = item.marker.itemNumber ?? (baseNumber + numberedCount)
                numberedCount += 1
                prefix = "\(num). "
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
                ruleName: "list_\(item.marker.category)",
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
