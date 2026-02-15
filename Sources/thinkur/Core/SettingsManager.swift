import Foundation
import Combine

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var hotkeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(hotkeyCode), forKey: "hotkeyCode") }
    }

    @Published var vadThreshold: Float {
        didSet { UserDefaults.standard.set(vadThreshold, forKey: "vadThreshold") }
    }

    @Published var postProcessingEnabled: Bool {
        didSet { UserDefaults.standard.set(postProcessingEnabled, forKey: "postProcessingEnabled") }
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
    }
}
