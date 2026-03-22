import Testing
import NaturalLanguage
@testable import thinkur

@Suite("NLTaggerHelper")
struct NLTaggerHelperTests {
    @Test func lexicalClassReturnsTagForValidWord() {
        let tag = NLTaggerHelper.lexicalClass(of: "run", in: "I run fast", at: 1)
        #expect(tag != nil)
    }

    @Test func lexicalClassReturnsNilForOutOfBoundsIndex() {
        let tag = NLTaggerHelper.lexicalClass(of: "missing", in: "hello world", at: 10)
        #expect(tag == nil)
    }

    @Test func lexicalClassIdentifiesNoun() {
        let tag = NLTaggerHelper.lexicalClass(of: "dog", in: "the dog barks", at: 1)
        #expect(tag == .noun)
    }

    @Test func lexicalClassIdentifiesVerb() {
        let tag = NLTaggerHelper.lexicalClass(of: "runs", in: "she runs quickly", at: 1)
        #expect(tag == .verb)
    }

    @Test func isProperNounDetectsPersonalName() {
        let result = NLTaggerHelper.isProperNoun("John", in: "John went to the store")
        #expect(result == true)
    }

    @Test func isProperNounReturnsFalseForCommonWord() {
        let result = NLTaggerHelper.isProperNoun("the", in: "the cat sat on the mat")
        #expect(result == false)
    }

    @Test func nameTagReturnsPersonalNameForKnownName() {
        let tag = NLTaggerHelper.nameTag(for: "Paris", in: "I visited Paris last summer")
        #expect(tag == .placeName)
    }

    @Test func nameTagReturnsNilForCommonWord() {
        let tag = NLTaggerHelper.nameTag(for: "table", in: "the table is wooden")
        #expect(tag == nil)
    }

    @Test func lexicalClassWorksForFirstWord() {
        let tag = NLTaggerHelper.lexicalClass(of: "the", in: "the quick brown fox", at: 0)
        #expect(tag == .determiner)
    }
}
