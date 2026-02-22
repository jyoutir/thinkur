import Foundation
import SwiftData

@Model
final class AppStylePreference {
    @Attribute(.unique) var bundleID: String
    var appName: String
    var style: String

    init(bundleID: String, appName: String, style: String) {
        self.bundleID = bundleID
        self.appName = appName
        self.style = style
    }
}
