import Testing
import SwiftData
@testable import thinkur

@Suite("StylePreferenceService", .serialized)
struct StylePreferenceServiceTests {
    @MainActor
    private func makeService() -> StylePreferenceService {
        let schema = Schema([AppStylePreference.self])
        let container = SwiftDataContainerFactory.createInMemory(schema: schema)
        return StylePreferenceService(container: container)
    }

    @Test @MainActor func setAndGetStyle() async throws {
        let service = makeService()
        try await service.setStyle(for: "com.test.app", appName: "TestApp", style: "casual")
        let style = await service.getStyle(for: "com.test.app")
        #expect(style == "casual")
    }

    @Test @MainActor func updateExistingStyle() async throws {
        let service = makeService()
        try await service.setStyle(for: "com.test.app", appName: "TestApp", style: "casual")
        try await service.setStyle(for: "com.test.app", appName: "TestApp", style: "formal")
        let style = await service.getStyle(for: "com.test.app")
        #expect(style == "formal")
    }

    @Test @MainActor func getStyleReturnsNilForMissing() async {
        let service = makeService()
        let style = await service.getStyle(for: "com.nonexistent")
        #expect(style == nil)
    }

    @Test @MainActor func fetchAllReturnsAllPreferences() async throws {
        let service = makeService()
        try await service.setStyle(for: "com.app1", appName: "App1", style: "casual")
        try await service.setStyle(for: "com.app2", appName: "App2", style: "formal")
        let all = await service.fetchAll()
        #expect(all.count == 2)
    }
}
