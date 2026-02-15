import Foundation
import SwiftData
import os

@MainActor
final class StylePreferenceService {
    private let container: ModelContainer

    init() {
        do {
            let schema = Schema([AppStylePreference.self])
            let config = ModelConfiguration(
                "stylePreferences",
                schema: schema,
                url: Constants.appSupportDirectory.appendingPathComponent("stylePreferences.store")
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger.app.error("Failed to create style preferences ModelContainer: \(error)")
            do {
                let schema = Schema([AppStylePreference.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Cannot create even in-memory style preferences ModelContainer: \(error)")
            }
        }
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
}
