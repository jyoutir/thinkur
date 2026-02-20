import Testing
@testable import thinkur

@Suite("WhisperArtifactFilter")
struct WhisperArtifactFilterTests {

    @Test func blankAudioStripped() {
        #expect(WhisperArtifactFilter.strip("[BLANK_AUDIO]") == nil)
    }

    @Test func musicStripped() {
        #expect(WhisperArtifactFilter.strip("[Music]") == nil)
    }

    @Test func silenceStripped() {
        #expect(WhisperArtifactFilter.strip("[Silence]") == nil)
    }

    @Test func mixedTextPreservesRealWords() {
        let result = WhisperArtifactFilter.strip("hello [BLANK_AUDIO] world")
        #expect(result == "hello world")
    }

    @Test func realTextUnchanged() {
        let input = "the quick brown fox"
        #expect(WhisperArtifactFilter.strip(input) == input)
    }

    @Test func caseInsensitive() {
        #expect(WhisperArtifactFilter.strip("[blank_audio]") == nil)
        #expect(WhisperArtifactFilter.strip("[MUSIC]") == nil)
    }

    @Test func isArtifactDetectsToken() {
        #expect(WhisperArtifactFilter.isArtifact("[BLANK_AUDIO]"))
        #expect(!WhisperArtifactFilter.isArtifact("hello"))
    }

    @Test func multipleTokensStripped() {
        let result = WhisperArtifactFilter.strip("[BLANK_AUDIO] [Music] actual text [Noise]")
        #expect(result == "actual text")
    }

    // --- New: parenthesized annotations ---

    @Test func parenthesizedAnnotationStripped() {
        #expect(WhisperArtifactFilter.strip("(sniffling)") == nil)
        #expect(WhisperArtifactFilter.strip("(coughing)") == nil)
        #expect(WhisperArtifactFilter.strip("(laughing)") == nil)
    }

    @Test func spacedBracketsStripped() {
        #expect(WhisperArtifactFilter.strip("[ Silence ]") == nil)
        #expect(WhisperArtifactFilter.strip("[ BLANK_AUDIO ]") == nil)
    }

    @Test func mixedTextWithParenAnnotation() {
        let result = WhisperArtifactFilter.strip("Hello (coughing) world")
        #expect(result == "Hello world")
    }

    @Test func multipleAnnotationsAllStripped() {
        #expect(WhisperArtifactFilter.strip("(laughing) [noise]") == nil)
        #expect(WhisperArtifactFilter.strip("[music] (sniffling) [silence]") == nil)
    }

    @Test func isArtifactCatchesParenWrapped() {
        #expect(WhisperArtifactFilter.isArtifact("(sniffling)"))
        #expect(WhisperArtifactFilter.isArtifact("(coughing)"))
    }

    @Test func isArtifactCatchesBracketWrapped() {
        #expect(WhisperArtifactFilter.isArtifact("[ Silence ]"))
        #expect(WhisperArtifactFilter.isArtifact("[unknown]"))
    }

    @Test func isArtifactRejectsNormalWords() {
        #expect(!WhisperArtifactFilter.isArtifact("hello"))
        #expect(!WhisperArtifactFilter.isArtifact("world"))
    }
}
