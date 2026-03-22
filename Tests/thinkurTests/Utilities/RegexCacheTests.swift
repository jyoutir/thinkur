import Testing
@testable import thinkur

@Suite("RegexCache")
struct RegexCacheTests {
    @Test func returnsSameRegexForSamePattern() {
        let cache = RegexCache()
        let first = cache.regex(for: "hello")
        let second = cache.regex(for: "hello")
        #expect(first === second)
    }

    @Test func returnsNilForInvalidPattern() {
        let cache = RegexCache()
        let result = cache.regex(for: "[invalid")
        #expect(result == nil)
    }

    @Test func differentOptionsProduceDifferentEntries() {
        let cache = RegexCache()
        let caseInsensitive = cache.regex(for: "hello", options: .caseInsensitive)
        let caseSensitive = cache.regex(for: "hello", options: [])
        #expect(caseInsensitive !== caseSensitive)
    }
}
