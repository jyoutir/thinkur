import Testing
import Foundation
import Cocoa
@testable import thinkur

@Suite("SettingsManager", .serialized)
struct SettingsManagerTests {
    @MainActor
    private func makeSettings() -> (SettingsManager, UserDefaults) {
        let suiteName = "com.thinkur.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = SettingsManager(defaults: defaults)
        return (settings, defaults)
    }

    @Test @MainActor func defaultValues() {
        let (settings, _) = makeSettings()
        #expect(settings.postProcessingEnabled == true)
        #expect(settings.soundEffects == true)
        #expect(settings.floatingIndicator == true)
        #expect(settings.automaticUpdates == true)
        #expect(settings.removeFillerWords == true)
        #expect(settings.intentCorrection == true)
        #expect(settings.smartFormatting == true)
        #expect(settings.themeMode == .dark)
        #expect(settings.vadThreshold == 0.3)
        #expect(settings.hotkeyShortcutOption == .custom)
        #expect(settings.effectiveHotkeyCode == Constants.tabKeyCode)
        #expect(settings.effectiveHotkeyModifiers == 0)
        #expect(settings.effectiveHotkeyBinding == HotkeyBinding(keyCode: Constants.tabKeyCode, modifiers: 0))
    }

    @Test @MainActor func setValuePersistsToDefaults() {
        let (settings, defaults) = makeSettings()
        settings.postProcessingEnabled = false
        #expect(defaults.bool(forKey: "postProcessingEnabled") == false)
    }

    @Test @MainActor func setHotkeyCodePersists() {
        let (settings, defaults) = makeSettings()
        settings.hotkeyCode = 49 // Space
        #expect(defaults.integer(forKey: "hotkeyCode") == 49)
    }

    @Test @MainActor func selectRightOptionPersistsAndAppliesPreset() {
        let (settings, defaults) = makeSettings()
        settings.selectHotkeyShortcutOption(.rightOption)
        #expect(defaults.string(forKey: "hotkeyShortcutOption") == "rightOption")
        #expect(settings.effectiveHotkeyCode == Constants.rightOptionKeyCode)
        #expect(settings.effectiveHotkeyModifiers == 0)
        #expect(settings.effectiveHotkeyBinding == HotkeyBinding(keyCode: Constants.rightOptionKeyCode, modifiers: 0))
    }

    @Test @MainActor func presetSelectionPreservesCustomShortcut() {
        let (settings, _) = makeSettings()
        settings.applyCustomHotkey(keyCode: 49, modifiers: UInt(NSEvent.ModifierFlags.command.rawValue))
        settings.selectHotkeyShortcutOption(.rightCommand)
        #expect(settings.effectiveHotkeyCode == Constants.rightCommandKeyCode)
        #expect(settings.effectiveHotkeyModifiers == 0)

        settings.selectHotkeyShortcutOption(.custom)
        #expect(settings.effectiveHotkeyCode == 49)
        #expect(settings.effectiveHotkeyModifiers == UInt(NSEvent.ModifierFlags.command.rawValue))
        #expect(settings.effectiveHotkeyBinding == HotkeyBinding(
            keyCode: 49,
            modifiers: UInt(NSEvent.ModifierFlags.command.rawValue)
        ))
    }

    @Test @MainActor func setThemeModePersists() {
        let (settings, defaults) = makeSettings()
        settings.themeMode = .dark
        #expect(defaults.string(forKey: "themeMode") == "dark")
    }

    @Test @MainActor func setVadThresholdPersists() {
        let (settings, defaults) = makeSettings()
        settings.vadThreshold = 0.7
        #expect(defaults.float(forKey: "vadThreshold") == 0.7)
    }

    @Test @MainActor func isolatedSuitesDontLeak() {
        let (settings1, _) = makeSettings()
        let (settings2, _) = makeSettings()
        settings1.postProcessingEnabled = false
        #expect(settings2.postProcessingEnabled == true)
    }
}
