import SwiftUI

@main
struct thinkurApp: App {
    @State private var coordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("thinkur", systemImage: coordinator.menuBarViewModel.menuBarIcon) {
            MenuBarView()
                .environment(coordinator)
                .environment(coordinator.menuBarViewModel)
                .environment(coordinator.permissionViewModel)
                .environment(coordinator.recordingViewModel)
                .environment(coordinator.transcriptionViewModel)
        }
        .menuBarExtraStyle(.window)

        Window("thinkur", id: "main") {
            if coordinator.onboardingViewModel.isComplete {
                MainWindowView()
                    .environment(coordinator)
                    .environment(coordinator.menuBarViewModel)
                    .environment(coordinator.permissionViewModel)
                    .environment(coordinator.recordingViewModel)
                    .environment(coordinator.transcriptionViewModel)
                    .environment(coordinator.homeViewModel)
                    .environment(coordinator.shortcutsViewModel)
                    .environment(coordinator.styleViewModel)
                    .environment(coordinator.insightsViewModel)
                    .environment(SettingsManager.shared)
            } else {
                OnboardingFlow()
                    .environment(coordinator)
                    .environment(coordinator.onboardingViewModel)
                    .environment(coordinator.permissionViewModel)
            }
        }
        .defaultSize(width: 920, height: 620)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance runs — kill duplicates
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jyo.thinkur"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            // Another instance is already running — quit this one
            NSApplication.shared.terminate(nil)
            return
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
