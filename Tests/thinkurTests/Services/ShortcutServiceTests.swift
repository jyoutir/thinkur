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

    @Test @MainActor func deleteRemovesShortcut() async throws {
        let service = makeService()
        try await service.add(trigger: "ty", expansion: "thank you")
        let all = await service.fetchAll()
        #expect(all.count == 1)
        try await service.delete(all.first!)
        let afterDelete = await service.fetchAll()
        #expect(afterDelete.isEmpty)
    }

    @Test @MainActor func findExpansionReturnsCorrectValue() async throws {
        let service = makeService()
        try await service.add(trigger: "omw", expansion: "on my way")
        let expansion = await service.findExpansion(for: "omw")
        #expect(expansion == "on my way")
    }

    @Test @MainActor func findExpansionReturnsNilForMissing() async {
        let service = makeService()
        let expansion = await service.findExpansion(for: "nonexistent")
        #expect(expansion == nil)
    }

    @Test @MainActor func triggerIsTrimmed() async throws {
        let service = makeService()
        try await service.add(trigger: "  brb  ", expansion: "be right back")
        let expansion = await service.findExpansion(for: "brb")
        #expect(expansion == "be right back")
    }
}
