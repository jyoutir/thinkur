import Foundation
import SwiftData
import os

@MainActor
final class ShortcutService: ShortcutLookup {
    private let container: ModelContainer

    init() {
        let schema = Schema([Shortcut.self])
        container = SwiftDataContainerFactory.create(
            name: "shortcuts",
            schema: schema,
            storeURL: Constants.appSupportDirectory.appendingPathComponent("shortcuts.store")
        )
    }

    init(container: ModelContainer) {
        self.container = container
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
        let descriptor = FetchDescriptor<Shortcut>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.contains(where: { $0.trigger.caseInsensitiveCompare(trimmedTrigger) == .orderedSame }) {
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

    func applyShortcuts(to text: String) async -> String {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Shortcut>()
        guard let shortcuts = try? context.fetch(descriptor), !shortcuts.isEmpty else { return text }

        // Process longest triggers first to prevent partial matches
        let sorted = shortcuts.sorted { $0.trigger.count > $1.trigger.count }

        var result = text
        for shortcut in sorted {
            let escaped = NSRegularExpression.escapedPattern(for: shortcut.trigger)
            // Consume trailing sentence punctuation (.!?) only at end of text —
            // that's always auto-added by post-processing, not spoken.
            guard let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b(?:[.!?]+(?=\\s*$))?",
                options: .caseInsensitive
            ) else { continue }

            let template = NSRegularExpression.escapedTemplate(for: shortcut.expansion)
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: template
            )
        }

        return result
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
