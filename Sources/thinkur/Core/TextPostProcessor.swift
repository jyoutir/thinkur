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
                Logger.postProcessing.debug("\(processor.name): \"\(before)\" → \"\(currentText)\"")
            }
        }
        return ProcessorResult(text: currentText, corrections: allCorrections)
    }
}
