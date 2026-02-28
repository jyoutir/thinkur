import Foundation
import SwiftUI
import ServiceManagement

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults: UserDefaults

    var hotkeyCode: UInt16 {
        didSet { defaults.set(Int(hotkeyCode), forKey: "hotkeyCode") }
    }

    var hotkeyModifiers: UInt {
        didSet { defaults.set(Int(hotkeyModifiers), forKey: "hotkeyModifiers") }
    }

    var vadThreshold: Float {
        didSet { defaults.set(vadThreshold, forKey: "vadThreshold") }
    }

    var postProcessingEnabled: Bool {
        didSet { defaults.set(postProcessingEnabled, forKey: "postProcessingEnabled") }
    }

    // Hotkey settings
    var hotkeyHoldMode: Bool {
        didSet { defaults.set(hotkeyHoldMode, forKey: "hotkeyHoldMode") }
    }

    // System settings
    var soundEffects: Bool {
        didSet { defaults.set(soundEffects, forKey: "soundEffects") }
    }

    var soundStyle: String {
        didSet { defaults.set(soundStyle, forKey: "soundStyle") }
    }

    var dimMusicWhileRecording: Bool {
        didSet { defaults.set(dimMusicWhileRecording, forKey: "pauseMusicWhileRecording") }
    }

    var floatingIndicator: Bool {
        didSet { defaults.set(floatingIndicator, forKey: "floatingIndicator") }
    }

    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    var automaticUpdates: Bool {
        didSet { defaults.set(automaticUpdates, forKey: "automaticUpdates") }
    }

    var analyticsEnabled: Bool {
        didSet { defaults.set(analyticsEnabled, forKey: "analyticsEnabled") }
    }

    // Dictation settings
    var removeFillerWords: Bool {
        didSet { defaults.set(removeFillerWords, forKey: "removeFillerWords") }
    }

    var intentCorrection: Bool {
        didSet { defaults.set(intentCorrection, forKey: "intentCorrection") }
    }

    var smartFormatting: Bool {
        didSet { defaults.set(smartFormatting, forKey: "smartFormatting") }
    }

    var listFormatting: Bool {
        didSet { defaults.set(listFormatting, forKey: "listFormatting") }
    }

    // Theme
    var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: "themeMode") }
    }

    // Accent color
    var accentColorName: String {
        didSet { defaults.set(accentColorName, forKey: "accentColorName") }
    }

    var accentColor: Color {
        (AccentColor(rawValue: accentColorName) ?? .defaultGreen).color
    }

    var accentUITint: Color {
        (AccentColor(rawValue: accentColorName) ?? .defaultGreen).uiTintColor
    }

    // Onboarding
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    private convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults

        if defaults.object(forKey: "hotkeyCode") == nil {
            defaults.set(Int(Constants.tabKeyCode), forKey: "hotkeyCode")
        }
        if defaults.object(forKey: "vadThreshold") == nil {
            defaults.set(Float(0.3), forKey: "vadThreshold")
        }
        if defaults.object(forKey: "postProcessingEnabled") == nil {
            defaults.set(true, forKey: "postProcessingEnabled")
        }

        self.hotkeyCode = UInt16(defaults.integer(forKey: "hotkeyCode"))
        self.hotkeyModifiers = UInt(defaults.integer(forKey: "hotkeyModifiers"))
        self.vadThreshold = defaults.float(forKey: "vadThreshold")
        self.postProcessingEnabled = defaults.bool(forKey: "postProcessingEnabled")
        // Hotkey
        self.hotkeyHoldMode = defaults.bool(forKey: "hotkeyHoldMode")

        // System - with sensible defaults
        self.soundEffects = defaults.object(forKey: "soundEffects") != nil ? defaults.bool(forKey: "soundEffects") : true
        self.soundStyle = defaults.string(forKey: "soundStyle") ?? "chime"
        self.dimMusicWhileRecording = defaults.object(forKey: "pauseMusicWhileRecording") != nil ? defaults.bool(forKey: "pauseMusicWhileRecording") : true
        self.floatingIndicator = defaults.object(forKey: "floatingIndicator") != nil ? defaults.bool(forKey: "floatingIndicator") : true
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.automaticUpdates = defaults.object(forKey: "automaticUpdates") != nil ? defaults.bool(forKey: "automaticUpdates") : true
        self.analyticsEnabled = defaults.object(forKey: "analyticsEnabled") != nil ? defaults.bool(forKey: "analyticsEnabled") : true

        // Dictation - defaults true
        self.removeFillerWords = defaults.object(forKey: "removeFillerWords") != nil ? defaults.bool(forKey: "removeFillerWords") : true
        self.intentCorrection = defaults.object(forKey: "intentCorrection") != nil ? defaults.bool(forKey: "intentCorrection") : true
        self.smartFormatting = defaults.object(forKey: "smartFormatting") != nil ? defaults.bool(forKey: "smartFormatting") : true
        self.listFormatting = defaults.object(forKey: "listFormatting") != nil ? defaults.bool(forKey: "listFormatting") : true

        // Theme
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: "themeMode") ?? "") ?? .dark

        // Accent color (migrate removed "black" to green)
        let storedColor = defaults.string(forKey: "accentColorName") ?? AccentColor.defaultGreen.rawValue
        self.accentColorName = AccentColor(rawValue: storedColor) != nil ? storedColor : AccentColor.defaultGreen.rawValue

        // Onboarding
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }
}
