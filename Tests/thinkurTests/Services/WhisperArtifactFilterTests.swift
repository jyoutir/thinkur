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

    @Test func unknownBracketsUnchanged() {
        // Brackets not on allowlist must pass through (e.g. markdown, code)
        let input = "myArray[0] and [link](url)"
        #expect(WhisperArtifactFilter.strip(input) == input)
    }

    @Test func caseInsensitive() {
        #expect(WhisperArtifactFilter.strip("[blank_audio]") == nil)
        #expect(WhisperArtifactFilter.strip("[MUSIC]") == nil)
    }

    @Test func isArtifactDetectsToken() {
        #expect(WhisperArtifactFilter.isArtifact("[BLANK_AUDIO]"))
        #expect(!WhisperArtifactFilter.isArtifact("hello"))
        #expect(!WhisperArtifactFilter.isArtifact("[0]"))
    }

    @Test func multipleTokensStripped() {
        let result = WhisperArtifactFilter.strip("[BLANK_AUDIO] [Music] actual text [Noise]")
        #expect(result == "actual text")
    }
}
