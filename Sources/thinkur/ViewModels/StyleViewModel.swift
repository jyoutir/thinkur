import Foundation

struct StyleAppEntry: Identifiable {
    let id: String // bundleID
    let appName: String
    let description: String
    var style: String
    let iconColor: String // for AppIconView
}

@MainActor
@Observable
final class StyleViewModel {
    var stylePreferences: [StyleAppEntry] = []

    private let stylePreferenceService: StylePreferenceService

    private static let defaultApps: [(bundleID: String, appName: String, description: String, iconColor: String)] = [
        ("com.tinyspeck.slackmacgap", "Slack", "Casual, friendly tone", "purple"),
        ("com.apple.mail", "Mail", "Professional, formal tone", "blue"),
        ("com.apple.Notes", "Notes", "Natural, balanced tone", "yellow"),
    ]

    init(stylePreferenceService: StylePreferenceService) {
        self.stylePreferenceService = stylePreferenceService
    }

    func loadData() async {
        var entries: [StyleAppEntry] = []
        for app in Self.defaultApps {
            let style = await stylePreferenceService.getStyle(for: app.bundleID) ?? "Standard"
            entries.append(StyleAppEntry(
                id: app.bundleID,
                appName: app.appName,
                description: app.description,
                style: style,
                iconColor: app.iconColor
            ))
        }
        stylePreferences = entries
    }

    func updateStyle(for bundleID: String, style: String) async {
        guard let entry = stylePreferences.first(where: { $0.id == bundleID }) else { return }
        try? await stylePreferenceService.setStyle(for: bundleID, appName: entry.appName, style: style)
        await loadData()
    }
}
