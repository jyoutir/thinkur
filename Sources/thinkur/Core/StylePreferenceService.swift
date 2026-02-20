import Foundation
import SwiftData
import os

@MainActor
final class StylePreferenceService {
    private let container: ModelContainer

    init() {
        let schema = Schema([AppStylePreference.self])
        container = SwiftDataContainerFactory.create(
            name: "stylePreferences",
            schema: schema,
            storeURL: Constants.appSupportDirectory.appendingPathComponent("stylePreferences.store")
        )
    }

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async -> [AppStylePreference] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<AppStylePreference>()
        descriptor.sortBy = [SortDescriptor(\.appName)]
        return (try? context.fetch(descriptor)) ?? []
    }

    func setStyle(for bundleID: String, appName: String, style: String) async throws {
        let context = container.mainContext
        let predicate = #Predicate<AppStylePreference> { $0.bundleID == bundleID }
        let descriptor = FetchDescriptor<AppStylePreference>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            existing.style = style
        } else {
            let pref = AppStylePreference(bundleID: bundleID, appName: appName, style: style)
            context.insert(pref)
        }
        try context.save()
    }

    func getStyle(for bundleID: String) async -> String? {
        let context = container.mainContext
        let predicate = #Predicate<AppStylePreference> { $0.bundleID == bundleID }
        let descriptor = FetchDescriptor<AppStylePreference>(predicate: predicate)
        return try? context.fetch(descriptor).first?.style
    }

    func removeStyle(for bundleID: String) async throws {
        let context = container.mainContext
        let predicate = #Predicate<AppStylePreference> { $0.bundleID == bundleID }
        let descriptor = FetchDescriptor<AppStylePreference>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }
}
