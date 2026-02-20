import Foundation

@MainActor
protocol ShortcutLookup {
    func applyShortcuts(to text: String) async -> String
}
