import Foundation

/// Persists custom display names for smart lights in UserDefaults
@MainActor
final class LightNameStore {
    private static let defaultsKey = "smartHomeLightCustomNames"
    private nonisolated(unsafe) let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// All stored custom names: [lightID: customName]
    private var customNames: [String: String] {
        get { defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Self.defaultsKey) }
    }

    /// Returns the custom display name for a light, or nil if none set
    func displayName(for lightID: String) -> String? {
        customNames[lightID]
    }

    /// Persist a custom name for a light
    func setCustomName(_ name: String, for lightID: String) {
        var names = customNames
        names[lightID] = name
        customNames = names
    }

    /// Remove the custom name, reverting to the hardware name
    func removeCustomName(for lightID: String) {
        var names = customNames
        names.removeValue(forKey: lightID)
        customNames = names
    }

    /// Apply stored custom names to a lights array, preserving originalName
    func applyCustomNames(to lights: inout [SmartLight]) {
        let names = customNames
        for i in lights.indices {
            if let custom = names[lights[i].id] {
                lights[i].name = custom
            }
        }
    }
}
