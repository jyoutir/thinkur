import Foundation

/// Background actor for running text post-processing off the main thread.
/// Prevents UI blocking during transcription post-processing (200-500ms typical).
actor PostProcessingActor {
    private let processor: TextPostProcessor

    init(processor: TextPostProcessor) {
        self.processor = processor
    }

    func process(
        _ text: String,
        context: ProcessingContext,
        disabledProcessors: Set<String> = []
    ) -> ProcessorResult {
        processor.process(text, context: context, disabledProcessors: disabledProcessors)
    }
}
