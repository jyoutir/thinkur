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
                .environment(coordinator.permissionManager)
                .environment(coordinator.recordingViewModel)
                .environment(coordinator.settings)
        }
        .menuBarExtraStyle(.window)

        Window("thinkur", id: "main") {
            RootView()
                .environment(coordinator)
                .environment(coordinator.menuBarViewModel)
                .environment(coordinator.permissionManager)
                .environment(coordinator.recordingViewModel)
                .environment(coordinator.homeViewModel)
                .environment(coordinator.shortcutsViewModel)
                .environment(coordinator.styleViewModel)
                .environment(coordinator.insightsViewModel)
                .environment(coordinator.onboardingViewModel)
                .environment(coordinator.settings)
        }
        .defaultSize(width: 920, height: 620)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
    }
}

/// Single root view that switches between onboarding and main window.
/// All environment objects are injected once at the Window level,
/// so transitions between states never invalidate environment references.
private struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if coordinator.onboardingViewModel.isComplete {
                MainWindowView()
            } else {
                OnboardingFlow()
            }
        }
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
