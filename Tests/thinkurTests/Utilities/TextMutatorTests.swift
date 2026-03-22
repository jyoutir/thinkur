import Testing
@testable import thinkur

@Suite("TextMutator")
struct TextMutatorTests {
    @Test func replaceAllFindsAndReplacesMatches() {
        let (result, mutations) = TextMutator.replaceAll(in: "hello world hello", pattern: "hello", replacement: "hi")
        #expect(result == "hi world hi")
        #expect(mutations.count == 2)
    }

    @Test func replaceAllWithNoMatchesReturnsOriginal() {
        let (result, mutations) = TextMutator.replaceAll(in: "hello world", pattern: "xyz", replacement: "abc")
        #expect(result == "hello world")
        #expect(mutations.isEmpty)
    }

    @Test func replaceLiteralReplacesWholeWordOnly() {
        let (result, _) = TextMutator.replaceLiteral(in: "cat concatenate cat", phrase: "cat", replacement: "dog")
        #expect(result == "dog concatenate dog")
    }

    @Test func mutationsContainCorrectOriginals() {
        let (_, mutations) = TextMutator.replaceAll(in: "foo bar foo", pattern: "foo", replacement: "baz")
        #expect(mutations.count == 2)
        #expect(mutations[0].original == "foo")
        #expect(mutations[0].replacement == "baz")
        #expect(mutations[1].original == "foo")
    }
}
