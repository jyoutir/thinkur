import Foundation
import Cocoa

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
    private let analyticsService: any AnalyticsRecording

    private static let defaultApps: [(bundleID: String, appName: String, description: String, iconColor: String)] = [
        ("com.tinyspeck.slackmacgap", "Slack", "Casual, friendly tone", "purple"),
        ("com.apple.mail", "Mail", "Professional, formal tone", "blue"),
        ("com.apple.Notes", "Notes", "Natural, balanced tone", "yellow"),
    ]

    init(stylePreferenceService: StylePreferenceService, analyticsService: any AnalyticsRecording) {
        self.stylePreferenceService = stylePreferenceService
        self.analyticsService = analyticsService
    }

    func loadData() async {
        let usageRecords = await analyticsService.fetchTopApps(limit: 100)
        let storedPrefs = await stylePreferenceService.fetchAll()

        var entries: [StyleAppEntry] = []
        var seenBundleIDs: Set<String> = []

        // Add all apps the user has dictated into
        for usage in usageRecords {
            let style = storedPrefs.first(where: { $0.bundleID == usage.bundleID })?.style ?? "Standard"
            entries.append(StyleAppEntry(
                id: usage.bundleID,
                appName: usage.appName,
                description: "\(usage.totalWords) words dictated",
                style: style,
                iconColor: "blue"
            ))
            seenBundleIDs.insert(usage.bundleID)
        }

        // Add stored preferences for manually-added apps not yet in the list
        for pref in storedPrefs where !seenBundleIDs.contains(pref.bundleID) {
            entries.append(StyleAppEntry(
                id: pref.bundleID,
                appName: pref.appName,
                description: "Custom style",
                style: pref.style,
                iconColor: "gray"
            ))
            seenBundleIDs.insert(pref.bundleID)
        }

        // Fallback defaults for new users with no usage data
        if entries.isEmpty {
            for app in Self.defaultApps {
                let style = storedPrefs.first(where: { $0.bundleID == app.bundleID })?.style ?? "Standard"
                entries.append(StyleAppEntry(
                    id: app.bundleID,
                    appName: app.appName,
                    description: app.description,
                    style: style,
                    iconColor: app.iconColor
                ))
            }
        }

        stylePreferences = entries
    }

    func updateStyle(for bundleID: String, style: String) async {
        guard let entry = stylePreferences.first(where: { $0.id == bundleID }) else { return }
        try? await stylePreferenceService.setStyle(for: bundleID, appName: entry.appName, style: style)
        await loadData()
    }

    func removeApp(bundleID: String) async {
        try? await stylePreferenceService.removeStyle(for: bundleID)
        await loadData()
    }

    func addApp(bundleID: String, appName: String) async {
        try? await stylePreferenceService.setStyle(for: bundleID, appName: appName, style: "Standard")
        await loadData()
    }

    /// Returns running regular apps not already in the style list
    var availableApps: [(bundleID: String, appName: String)] {
        let currentIDs = Set(stylePreferences.map(\.id))
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      !currentIDs.contains(bundleID) else { return nil }
                return (bundleID: bundleID, appName: app.localizedName ?? bundleID)
            }
            .sorted { $0.appName < $1.appName }
    }
}
