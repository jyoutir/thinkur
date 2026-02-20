import SwiftUI

@main
struct thinkurApp: App {
    @State private var coordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("thinkur", id: "main") {
            RootView()
                .environment(coordinator)
                .environment(coordinator.permissionManager)
                .environment(coordinator.recordingViewModel)
                .environment(coordinator.homeViewModel)
                .environment(coordinator.shortcutsViewModel)
                .environment(coordinator.styleViewModel)
                .environment(coordinator.insightsViewModel)
                .environment(coordinator.onboardingViewModel)
                .environment(coordinator.integrationsViewModel)
                .environment(coordinator.settings)
                .environment(coordinator.sharedState)
                .tint(.primary)
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
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        Group {
            if coordinator.onboardingViewModel.isComplete {
                MainWindowView()
            } else {
                OnboardingFlow()
            }
        }
        .preferredColorScheme(settings.themeMode.colorScheme)
        .onAppear { applyAppearance(settings.themeMode) }
        .onChange(of: settings.themeMode) { _, newMode in applyAppearance(newMode) }
    }

    private func applyAppearance(_ mode: ThemeMode) {
        NSApp.appearance = NSAppearance(named: mode == .dark ? .darkAqua : .aqua)
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

        // Always show in dock (no menu bar extra)
        NSApplication.shared.setActivationPolicy(.regular)

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
