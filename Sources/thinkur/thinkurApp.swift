import SwiftUI

@main
struct thinkurApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("thinkur", systemImage: coordinator.menuBarViewModel.menuBarIcon) {
            MenuBarView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.menuBarViewModel)
                .environmentObject(coordinator.permissionViewModel)
                .environmentObject(coordinator.recordingViewModel)
                .environmentObject(coordinator.transcriptionViewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The @StateObject in thinkurApp triggers setup.
        // We use this delegate to ensure the app stays alive as an agent app.
    }
}
