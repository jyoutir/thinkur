import Foundation

enum AppStyleMap {
    private static let styles: [String: AppStyle] = [
        // Casual
        "com.apple.MobileSMS": .casual,
        "com.apple.iChat": .casual,
        "com.tinyspeck.slackmacgap": .casual,
        "com.hnc.Discord": .casual,
        "org.whispersystems.signal-desktop": .casual,
        "ru.keepcoder.Telegram": .casual,
        // Formal
        "com.apple.mail": .formal,
        "com.microsoft.Outlook": .formal,
        "com.google.Chrome": .formal,
        "com.apple.Pages": .formal,
        "com.microsoft.Word": .formal,
        "com.apple.Notes": .formal,
        // Code
        "com.apple.dt.Xcode": .code,
        "com.microsoft.VSCode": .code,
        "com.sublimetext.4": .code,
        "com.jetbrains.intellij": .code,
        "dev.zed.Zed": .code,
    ]

    static func style(for bundleID: String) -> AppStyle {
        styles[bundleID] ?? .standard
    }
}
