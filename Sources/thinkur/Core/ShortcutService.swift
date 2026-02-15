import Foundation
import SwiftData
import os

@MainActor
final class ShortcutService {
    private let container: ModelContainer

    init() {
        do {
            let schema = Schema([Shortcut.self])
            let config = ModelConfiguration(
                "shortcuts",
                schema: schema,
                url: Constants.appSupportDirectory.appendingPathComponent("shortcuts.store")
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger.app.error("Failed to create shortcuts ModelContainer: \(error)")
            do {
                let schema = Schema([Shortcut.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Cannot create even in-memory shortcuts ModelContainer: \(error)")
            }
        }
    }

    func fetchAll() async -> [Shortcut] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<Shortcut>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return (try? context.fetch(descriptor)) ?? []
    }

    func add(trigger: String, expansion: String) async throws {
        let context = container.mainContext
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespaces)
        let predicate = #Predicate<Shortcut> { $0.trigger == trimmedTrigger }
        let descriptor = FetchDescriptor<Shortcut>(predicate: predicate)

        if let _ = try? context.fetch(descriptor).first {
            throw ShortcutError.duplicateTrigger
        }

        let shortcut = Shortcut(trigger: trimmedTrigger, expansion: expansion)
        context.insert(shortcut)
        try context.save()
    }

    func delete(_ shortcut: Shortcut) async throws {
        let context = container.mainContext
        context.delete(shortcut)
        try context.save()
    }

    func findExpansion(for text: String) async -> String? {
        let context = container.mainContext
        let predicate = #Predicate<Shortcut> { $0.trigger == text }
        let descriptor = FetchDescriptor<Shortcut>(predicate: predicate)
        return try? context.fetch(descriptor).first?.expansion
    }
}

enum ShortcutError: LocalizedError {
    case duplicateTrigger

    var errorDescription: String? {
        switch self {
        case .duplicateTrigger: return "A shortcut with this trigger already exists."
        }
    }
}
