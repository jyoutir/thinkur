import SwiftUI

@main
struct thinkurApp: App {
    @StateObject private var appState = AppStateManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("thinkur", systemImage: appState.menuBarIcon) {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The @StateObject in thinkurApp triggers setup.
        // We use this delegate to ensure the app stays alive as an agent app.
    }
}
