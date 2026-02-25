import SwiftUI
import Sparkle

@main
struct thinkurApp: App {
    @State private var coordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let updaterService = UpdaterService()

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
                .environment(coordinator.licenseManager)
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

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance runs — kill duplicates
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jyo.thinkur"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            NSApplication.shared.terminate(nil)
            return
        }

        // LSUIElement=true in Info.plist keeps us out of the dock.
        // Do NOT set .regular — that would override LSUIElement.

        // Create persistent menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "thinkur")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Intercept window close so it hides instead of destroying
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.title == "thinkur" }) {
                window.delegate = self
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Status Item Actions

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit thinkur", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil  // Reset so next left-click goes to action
        } else {
            toggleWindow()
        }
    }

    private func toggleWindow() {
        guard let window = NSApp.windows.first(where: { $0.title == "thinkur" }) else { return }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)  // Hide, don't destroy
        return false
    }
}
