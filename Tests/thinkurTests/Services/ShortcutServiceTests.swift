import Testing
import SwiftData
@testable import thinkur

@Suite("ShortcutService", .serialized)
struct ShortcutServiceTests {
    @MainActor
    private func makeService() -> ShortcutService {
        let schema = Schema([Shortcut.self])
        let container = SwiftDataContainerFactory.createInMemory(schema: schema)
        return ShortcutService(container: container)
    }

    @Test @MainActor func addAndFetchShortcut() async throws {
        let service = makeService()
        try await service.add(trigger: "brb", expansion: "be right back")
        let all = await service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.trigger == "brb")
        #expect(all.first?.expansion == "be right back")
    }

    @Test @MainActor func duplicateTriggerThrows() async throws {
        let service = makeService()
        try await service.add(trigger: "brb", expansion: "be right back")
        await #expect(throws: ShortcutError.self) {
            try await service.add(trigger: "brb", expansion: "something else")
        }
    }

    @Test @MainActor func duplicateTriggerIsCaseInsensitive() async throws {
        let service = makeService()
        try await service.add(trigger: "brb", expansion: "be right back")
        await #expect(throws: ShortcutError.self) {
            try await service.add(trigger: "BRB", expansion: "something else")
        }
    }

    @Test @MainActor func deleteRemovesShortcut() async throws {
        let service = makeService()
        try await service.add(trigger: "ty", expansion: "thank you")
        let all = await service.fetchAll()
        #expect(all.count == 1)
        try await service.delete(all.first!)
        let afterDelete = await service.fetchAll()
        #expect(afterDelete.isEmpty)
    }

    @Test @MainActor func triggerIsTrimmed() async throws {
        let service = makeService()
        try await service.add(trigger: "  brb  ", expansion: "be right back")
        let result = await service.applyShortcuts(to: "brb")
        #expect(result == "be right back")
    }

    // MARK: - applyShortcuts

    @Test @MainActor func wholeTextReplacement() async throws {
        let service = makeService()
        try await service.add(trigger: "omw", expansion: "on my way")
        let result = await service.applyShortcuts(to: "omw")
        #expect(result == "on my way")
    }

    @Test @MainActor func noMatchReturnsOriginal() async {
        let service = makeService()
        let result = await service.applyShortcuts(to: "nothing to replace here")
        #expect(result == "nothing to replace here")
    }

    @Test @MainActor func caseInsensitiveMatch() async throws {
        let service = makeService()
        try await service.add(trigger: "omw", expansion: "on my way")
        #expect(await service.applyShortcuts(to: "OMW") == "on my way")
        #expect(await service.applyShortcuts(to: "Omw") == "on my way")
    }

    @Test @MainActor func inlineReplacement() async throws {
        let service = makeService()
        try await service.add(trigger: "calendar", expansion: "https://cal.com/jyo")
        let result = await service.applyShortcuts(to: "Hello, here's my calendar, schedule one below.")
        #expect(result == "Hello, here's my https://cal.com/jyo, schedule one below.")
    }

    @Test @MainActor func inlineReplacementWithCapitalization() async throws {
        let service = makeService()
        try await service.add(trigger: "calendar", expansion: "https://cal.com/jyo")
        let result = await service.applyShortcuts(to: "Hello, here's my Calendar, schedule one below.")
        #expect(result == "Hello, here's my https://cal.com/jyo, schedule one below.")
    }

    @Test @MainActor func consumesTrailingPunctuationAtEndOfText() async throws {
        let service = makeService()
        try await service.add(trigger: "usage", expansion: "https://console.anthropic.com/usage")
        // Trailing period at end of text (auto-added by post-processing) is consumed
        #expect(await service.applyShortcuts(to: "Usage.") == "https://console.anthropic.com/usage")
        #expect(await service.applyShortcuts(to: "Usage!") == "https://console.anthropic.com/usage")
        // Mid-sentence punctuation is preserved
        #expect(await service.applyShortcuts(to: "Check usage, then continue.") == "Check https://console.anthropic.com/usage, then continue.")
        // Period mid-sentence (before more text) is preserved
        #expect(await service.applyShortcuts(to: "Check usage. Then continue.") == "Check https://console.anthropic.com/usage. Then continue.")
    }

    @Test @MainActor func doesNotMatchPartialWords() async throws {
        let service = makeService()
        try await service.add(trigger: "cal", expansion: "REPLACED")
        let result = await service.applyShortcuts(to: "calendar")
        #expect(result == "calendar")
    }

    @Test @MainActor func replacesMultipleOccurrences() async throws {
        let service = makeService()
        try await service.add(trigger: "brb", expansion: "be right back")
        let result = await service.applyShortcuts(to: "I'll brb, he'll brb too")
        #expect(result == "I'll be right back, he'll be right back too")
    }

    @Test @MainActor func multipleShortcutsInOneText() async throws {
        let service = makeService()
        try await service.add(trigger: "brb", expansion: "be right back")
        try await service.add(trigger: "omw", expansion: "on my way")
        let result = await service.applyShortcuts(to: "I'm omw and he's brb")
        #expect(result == "I'm on my way and he's be right back")
    }

    @Test @MainActor func longerTriggerMatchedFirst() async throws {
        let service = makeService()
        try await service.add(trigger: "hello", expansion: "hi")
        try await service.add(trigger: "hello world", expansion: "greetings earth")
        let result = await service.applyShortcuts(to: "hello world")
        #expect(result == "greetings earth")
    }
}
