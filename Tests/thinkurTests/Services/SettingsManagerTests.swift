import Testing
import Foundation
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
        #expect(settings.autoPunctuation == true)
        #expect(settings.intentCorrection == true)
        #expect(settings.smartFormatting == true)
        #expect(settings.selectedLanguage == "English")
        #expect(settings.modelSize == "small.en")
        #expect(settings.themeMode == .dark)
        #expect(settings.vadThreshold == 0.3)
    }

    @Test @MainActor func setValuePersistsToDefaults() {
        let (settings, defaults) = makeSettings()
        settings.postProcessingEnabled = false
        #expect(defaults.bool(forKey: "postProcessingEnabled") == false)
    }

    @Test @MainActor func setStringPersists() {
        let (settings, defaults) = makeSettings()
        settings.selectedLanguage = "Spanish"
        #expect(defaults.string(forKey: "selectedLanguage") == "Spanish")
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
        settings1.selectedLanguage = "French"
        #expect(settings2.selectedLanguage == "English")
    }
}
