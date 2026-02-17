import Foundation

enum AppStyleMap {
    static func style(for bundleID: String) -> AppStyle {
        StyleAdaptationRules.appStyleMap[bundleID] ?? .standard
    }
}
