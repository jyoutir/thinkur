import AppKit

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var cache: [String: NSImage?] = [:]

    private init() {}

    func icon(for bundleID: String) -> NSImage? {
        // Return cached if available
        if let cached = cache[bundleID] {
            return cached
        }

        // Load icon (expensive operation, happens once)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            cache[bundleID] = nil
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        cache[bundleID] = icon
        return icon
    }

    func clearCache() {
        cache.removeAll()
    }
}
