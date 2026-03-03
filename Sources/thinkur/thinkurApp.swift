import SwiftUI

@main
struct thinkurApp: App {
    @State private var coordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        appDelegate.telemetryService = coordinator.services.telemetryService
    }

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
                .environment(coordinator.meetingViewModel)
                .environment(coordinator.settings)
                .environment(coordinator.sharedState)
                .environment(coordinator.licenseManager)
                .environment(coordinator.telemetryService)
                .environment(coordinator.updaterService)
                .tint(coordinator.settings.accentUITint)
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
    @Environment(LicenseManager.self) private var licenseManager

    var body: some View {
        Group {
            if !coordinator.onboardingViewModel.isComplete || !coordinator.permissionManager.allGranted {
                OnboardingFlow()
            } else if licenseManager.status == .validating {
                ProgressView()
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            } else if !licenseManager.isLicensed {
                PaywallView()
            } else {
                MainWindowView()
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
    var telemetryService: TelemetryService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance runs — kill duplicates
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jyo.thinkur"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            NSApplication.shared.terminate(nil)
            return
        }

        // LSUIElement=true keeps the app as accessory (no dock icon) by default.
        // Switch to .regular so the dock icon shows. This ordering matters on
        // macOS 26 — starting as accessory avoids ViewBridge disconnections
        // that break TextField input in regular apps.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Stay running when window closes — hotkey + floating indicator remain active
    }

    func applicationWillTerminate(_ notification: Notification) {
        telemetryService?.sendPendingDigest()
    }
}

