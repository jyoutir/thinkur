import Foundation

@MainActor
@Observable
final class ShortcutsViewModel {
    var shortcuts: [Shortcut] = []
    var errorMessage: String?
    var newTrigger = ""
    var newExpansion = ""

    private let shortcutService: ShortcutService

    init(shortcutService: ShortcutService) {
        self.shortcutService = shortcutService
    }

    func loadData() async {
        shortcuts = await shortcutService.fetchAll()
    }

    func addShortcut() async {
        guard !newTrigger.isEmpty, !newExpansion.isEmpty else {
            errorMessage = "Both trigger and expansion are required."
            return
        }

        do {
            try await shortcutService.add(trigger: newTrigger, expansion: newExpansion)
            newTrigger = ""
            newExpansion = ""
            errorMessage = nil
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteShortcut(_ shortcut: Shortcut) async {
        do {
            try await shortcutService.delete(shortcut)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var shortcutCount: Int { shortcuts.count }
}
