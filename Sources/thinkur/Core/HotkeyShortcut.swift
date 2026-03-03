import KeyboardShortcuts
import Carbon.HIToolbox

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}

/// One-time migration from the old CGEvent-based hotkey settings (hotkeyCode / hotkeyModifiers)
/// to KeyboardShortcuts' Carbon-based storage. Runs once and sets a UserDefaults flag.
enum HotkeyMigration {
    private static let migrationKey = "hotkeyMigratedToKeyboardShortcuts"

    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: migrationKey) else { return }
        defaults.set(true, forKey: migrationKey)

        let keyCode = defaults.integer(forKey: "hotkeyCode")
        let modifierRaw = defaults.integer(forKey: "hotkeyModifiers")

        // Skip Fn/Globe key (63) — Carbon RegisterEventHotKey can't register modifier-only keys
        guard keyCode != 63, keyCode != 0 || modifierRaw != 0 else { return }

        let carbonModifiers = convertToCarbonModifiers(CGEventFlags(rawValue: UInt64(modifierRaw)))

        KeyboardShortcuts.setShortcut(
            .init(carbonKeyCode: keyCode, carbonModifiers: carbonModifiers),
            for: .toggleRecording
        )
    }

    /// Convert CGEventFlags bitmask to Carbon modifier flags.
    static func convertToCarbonModifiers(_ flags: CGEventFlags) -> Int {
        var carbon = 0
        if flags.contains(.maskCommand) { carbon |= cmdKey }
        if flags.contains(.maskAlternate) { carbon |= optionKey }
        if flags.contains(.maskControl) { carbon |= controlKey }
        if flags.contains(.maskShift) { carbon |= shiftKey }
        return carbon
    }
}
