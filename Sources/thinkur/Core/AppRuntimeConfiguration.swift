import Foundation

enum AppMode: String {
    case dev
    case release
}

enum AppRuntimeConfiguration {
    private static let info = Bundle.main.infoDictionary ?? [:]

    static let appMode: AppMode = {
        guard let raw = info["ThinkurAppMode"] as? String,
              let mode = AppMode(rawValue: raw) else {
            return .release
        }
        return mode
    }()

    static var isDevelopmentBuild: Bool { appMode == .dev }

    static let displayName: String = {
        (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? "thinkur"
    }()

    static let bundleIdentifier: String = {
        Bundle.main.bundleIdentifier ?? "com.jyo.thinkur"
    }()

    static let isSparkleEnabled: Bool = {
        (info["ThinkurEnableSparkle"] as? String)?.uppercased() == "YES"
    }()

    static let sparkleFeedURL: String = {
        (info["SUFeedURL"] as? String) ?? ""
    }()

    static let isTelemetryEnabled: Bool = {
        (info["ThinkurEnableTelemetry"] as? String)?.uppercased() == "YES"
    }()

    static let supportDirectoryName: String = {
        (info["ThinkurSupportDirName"] as? String) ?? "thinkur"
    }()

    static let sharedLicenseService: String = {
        (info["ThinkurSharedLicenseService"] as? String) ?? "com.jyo.thinkur.license"
    }()

    static let secretServicePrefix: String = {
        (info["ThinkurSecretServicePrefix"] as? String) ?? "com.jyo.thinkur"
    }()

    static let loggerSubsystem: String = {
        bundleIdentifier
    }()
}
