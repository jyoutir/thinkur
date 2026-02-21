import Foundation
import os

final class TextPostProcessor {
    private let processors: [TextProcessor]

    init(processors: [TextProcessor]) {
        self.processors = processors
    }

    func process(_ text: String, context: ProcessingContext, disabledProcessors: Set<String> = []) -> ProcessorResult {
        var currentText = text
        var allCorrections: [CorrectionEntry] = []
        for processor in processors {
            if disabledProcessors.contains(processor.name) {
                continue
            }
            let before = currentText
            let processorResult = processor.process(currentText, context: context)
            currentText = processorResult.text
            allCorrections.append(contentsOf: processorResult.corrections)
            if currentText != before {
                Logger.postProcessing.debug(
                    "\(processor.name) changed text length \(before.count) -> \(currentText.count)"
                )
            }
        }
        // Global cleanup: remove double punctuation after all processors
        currentText = cleanDoublePunctuation(currentText)

        return ProcessorResult(text: currentText, corrections: allCorrections)
    }

    private func cleanDoublePunctuation(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            (#"(?<!\.)([.!?])\s*[.](?!\.)"#, "$1"),   // sentence-ender absorbs following period (not within "...")
            (#",\s*,"#, ","),                            // collapse double commas
            (#"(?<!\.)\.{2}(?!\.)"#, "."),              // double period → single (not within "...")
        ]
        for (pattern, replacement) in patterns {
            guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: replacement)
        }
        return result
    }
}
