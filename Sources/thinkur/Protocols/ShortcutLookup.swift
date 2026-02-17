import Foundation

@MainActor
protocol ShortcutLookup {
    func findExpansion(for trigger: String) async -> String?
}
