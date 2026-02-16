import Foundation
import os

final class TextPostProcessor {
    private let processors: [TextProcessor]

    init(processors: [TextProcessor]) {
        self.processors = processors
    }

    func process(_ text: String, context: ProcessingContext, disabledProcessors: Set<String> = []) -> String {
        var result = text
        for processor in processors {
            if disabledProcessors.contains(processor.name) {
                continue
            }
            let before = result
            result = processor.process(result, context: context)
            if result != before {
                Logger.postProcessing.debug("\(processor.name): \"\(before)\" → \"\(result)\"")
            }
        }
        return result
    }
}
