import Testing
@testable import thinkur

@Suite("SmartHomeRenameMatcher")
struct SmartHomeRenameMatcherTests {

    @Test("Matches 'rename X to Y' pattern")
    func renameToPattern() {
        let result = SmartHomeRenameMatcher.matchRename(text: "rename lamp to desk light")
        #expect(result != nil)
        #expect(result?.oldName == "lamp")
        #expect(result?.newName == "desk light")
    }

    @Test("Matches 'call X Y' pattern")
    func callPattern() {
        let result = SmartHomeRenameMatcher.matchRename(text: "call lamp desk light")
        #expect(result != nil)
        #expect(result?.oldName == "lamp")
        #expect(result?.newName == "desk light")
    }

    @Test("Strips filler words before matching")
    func stripsFillers() {
        let result = SmartHomeRenameMatcher.matchRename(text: "hey please rename the lamp to desk light")
        #expect(result != nil)
        #expect(result?.oldName == "lamp")
        #expect(result?.newName == "desk light")
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let result = SmartHomeRenameMatcher.matchRename(text: "Rename Lamp To Desk Light")
        #expect(result != nil)
        #expect(result?.oldName == "lamp")
        #expect(result?.newName == "desk light")
    }

    @Test("Returns nil for non-rename text")
    func noMatch() {
        #expect(SmartHomeRenameMatcher.matchRename(text: "turn on the lamp") == nil)
        #expect(SmartHomeRenameMatcher.matchRename(text: "hello world") == nil)
        #expect(SmartHomeRenameMatcher.matchRename(text: "") == nil)
    }

    @Test("Handles multi-word light names")
    func multiWordNames() {
        let result = SmartHomeRenameMatcher.matchRename(text: "rename ceiling light to reading lamp")
        #expect(result != nil)
        #expect(result?.oldName == "ceiling light")
        #expect(result?.newName == "reading lamp")
    }
}
