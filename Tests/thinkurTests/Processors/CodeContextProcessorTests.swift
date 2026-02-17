import Testing
@testable import thinkur

@Suite("CodeContextProcessor")
struct CodeContextProcessorTests {
    let processor = CodeContextProcessor()

    private func codeCtx() -> ProcessingContext {
        ProcessingContext(
            frontmostAppBundleID: "com.apple.dt.Xcode",
            frontmostAppName: "Xcode",
            wordTimings: [],
            appStyle: .code
        )
    }

    private func standardCtx() -> ProcessingContext {
        ProcessingContext(
            frontmostAppBundleID: "com.test",
            frontmostAppName: "Test",
            wordTimings: [],
            appStyle: .standard
        )
    }

    // MARK: - Basic edge cases

    @Test func emptyString() {
        let result = processor.process("", context: codeCtx()).text
        #expect(result == "")
    }

    @Test func nonCodeContextPassthrough() {
        let result = processor.process("comment hello world", context: standardCtx()).text
        // In standard context, code processing is skipped — text unchanged
        #expect(result == "comment hello world")
    }

    // MARK: - Phase 1: Comments

    @Test func commentLine() {
        let result = processor.process("comment hello world", context: codeCtx()).text
        #expect(result.contains("//"))
        #expect(result.contains("hello world"))
    }

    @Test func docComment() {
        let result = processor.process("doc comment param name", context: codeCtx()).text
        #expect(result.contains("///"))
        #expect(result.contains("param name"))
    }

    @Test func todoAnnotation() {
        let result = processor.process("todo fix the bug", context: codeCtx()).text
        #expect(result.contains("TODO:"))
        #expect(result.contains("fix the bug"))
    }

    // MARK: - Phase 2: Casing commands

    @Test func camelCase() {
        let result = processor.process("camel case get user name", context: codeCtx()).text
        #expect(result.contains("getUserName"))
    }

    @Test func pascalCase() {
        let result = processor.process("pascal case my class", context: codeCtx()).text
        #expect(result.contains("MyClass"))
    }

    @Test func snakeCase() {
        let result = processor.process("snake case hello world", context: codeCtx()).text
        #expect(result.contains("hello_world"))
    }

    // MARK: - Phase 3: Operators

    @Test func equalsOperator() {
        let result = processor.process("x equals five", context: codeCtx()).text
        #expect(result.contains("="))
    }

    @Test func lessThanOperator() {
        let result = processor.process("x less than y", context: codeCtx()).text
        #expect(result.contains("<"))
    }

    // MARK: - Phase 4: Property access

    @Test func propertyAccess() {
        let result = processor.process("user dot name", context: codeCtx()).text
        #expect(result.contains("user.name"))
    }

    // MARK: - Correction metadata

    @Test func correctionMetadata() {
        let result = processor.process("comment hello world", context: codeCtx())
        #expect(!result.corrections.isEmpty)
        #expect(result.corrections.allSatisfy { $0.processorName == "CodeContext" })
    }
}
