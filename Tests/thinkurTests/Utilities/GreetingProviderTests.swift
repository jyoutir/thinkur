import Testing
@testable import thinkur

@Suite("GreetingProvider")
struct GreetingProviderTests {
    @Test func phrasesReturnsNonEmptyArray() {
        let result = GreetingProvider.phrases()
        #expect(!result.isEmpty)
    }

    @Test func formattedDateIsNonEmpty() {
        #expect(!GreetingProvider.formattedDate.isEmpty)
    }

    @Test func greetingContainsName() {
        let greeting = GreetingProvider.greeting()
        let name = GreetingProvider.firstName
        #expect(greeting.contains(name))
    }

    @Test func firstNameReturnsNonEmptyString() {
        #expect(!GreetingProvider.firstName.isEmpty)
    }
}
