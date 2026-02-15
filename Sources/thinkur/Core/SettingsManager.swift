import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    var hotkeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(hotkeyCode), forKey: "hotkeyCode") }
    }

    var vadThreshold: Float {
        didSet { UserDefaults.standard.set(vadThreshold, forKey: "vadThreshold") }
    }

    var postProcessingEnabled: Bool {
        didSet { UserDefaults.standard.set(postProcessingEnabled, forKey: "postProcessingEnabled") }
    }

    // Hotkey settings
    var hotkeyHoldMode: Bool {
        didSet { UserDefaults.standard.set(hotkeyHoldMode, forKey: "hotkeyHoldMode") }
    }

    // System settings
    var soundEffects: Bool {
        didSet { UserDefaults.standard.set(soundEffects, forKey: "soundEffects") }
    }

    var pauseMusicWhileRecording: Bool {
        didSet { UserDefaults.standard.set(pauseMusicWhileRecording, forKey: "pauseMusicWhileRecording") }
    }

    var floatingIndicator: Bool {
        didSet { UserDefaults.standard.set(floatingIndicator, forKey: "floatingIndicator") }
    }

    var showInDock: Bool {
        didSet { UserDefaults.standard.set(showInDock, forKey: "showInDock") }
    }

    var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    var automaticUpdates: Bool {
        didSet { UserDefaults.standard.set(automaticUpdates, forKey: "automaticUpdates") }
    }

    // Dictation settings
    var removeFillerWords: Bool {
        didSet { UserDefaults.standard.set(removeFillerWords, forKey: "removeFillerWords") }
    }

    var autoPunctuation: Bool {
        didSet { UserDefaults.standard.set(autoPunctuation, forKey: "autoPunctuation") }
    }

    var intentCorrection: Bool {
        didSet { UserDefaults.standard.set(intentCorrection, forKey: "intentCorrection") }
    }

    var smartFormatting: Bool {
        didSet { UserDefaults.standard.set(smartFormatting, forKey: "smartFormatting") }
    }

    var codeContext: Bool {
        didSet { UserDefaults.standard.set(codeContext, forKey: "codeContext") }
    }

    var learnFromCorrections: Bool {
        didSet { UserDefaults.standard.set(learnFromCorrections, forKey: "learnFromCorrections") }
    }

    // Language settings
    var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage") }
    }

    var multilingualMode: Bool {
        didSet { UserDefaults.standard.set(multilingualMode, forKey: "multilingualMode") }
    }

    var modelSize: String {
        didSet { UserDefaults.standard.set(modelSize, forKey: "modelSize") }
    }

    // Theme
    var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }

    private init() {
        let defaults = UserDefaults.standard

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
        self.vadThreshold = defaults.float(forKey: "vadThreshold")
        self.postProcessingEnabled = defaults.bool(forKey: "postProcessingEnabled")

        // Hotkey
        self.hotkeyHoldMode = defaults.bool(forKey: "hotkeyHoldMode")

        // System - with sensible defaults
        self.soundEffects = defaults.object(forKey: "soundEffects") != nil ? defaults.bool(forKey: "soundEffects") : true
        self.pauseMusicWhileRecording = defaults.bool(forKey: "pauseMusicWhileRecording")
        self.floatingIndicator = defaults.object(forKey: "floatingIndicator") != nil ? defaults.bool(forKey: "floatingIndicator") : true
        self.showInDock = defaults.bool(forKey: "showInDock")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.automaticUpdates = defaults.object(forKey: "automaticUpdates") != nil ? defaults.bool(forKey: "automaticUpdates") : true

        // Dictation - defaults true
        self.removeFillerWords = defaults.object(forKey: "removeFillerWords") != nil ? defaults.bool(forKey: "removeFillerWords") : true
        self.autoPunctuation = defaults.object(forKey: "autoPunctuation") != nil ? defaults.bool(forKey: "autoPunctuation") : true
        self.intentCorrection = defaults.object(forKey: "intentCorrection") != nil ? defaults.bool(forKey: "intentCorrection") : true
        self.smartFormatting = defaults.object(forKey: "smartFormatting") != nil ? defaults.bool(forKey: "smartFormatting") : true
        self.codeContext = defaults.bool(forKey: "codeContext")
        self.learnFromCorrections = defaults.bool(forKey: "learnFromCorrections")

        // Language
        self.selectedLanguage = defaults.string(forKey: "selectedLanguage") ?? "English"
        self.multilingualMode = defaults.bool(forKey: "multilingualMode")
        self.modelSize = defaults.string(forKey: "modelSize") ?? "small.en"

        // Theme
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: "themeMode") ?? "") ?? .system
    }
}
