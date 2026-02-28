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

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private weak var mainWindow: NSWindow?
    var telemetryService: TelemetryService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance runs — kill duplicates
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jyo.thinkur"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            NSApplication.shared.terminate(nil)
            return
        }

        // Create persistent menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = Self.makeMenuBarIcon()
            icon.accessibilityDescription = "thinkur"
            button.image = icon
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Window Discovery

    private func captureMainWindow() {
        // If we still have a valid ref, keep it
        if let w = mainWindow, w.isVisible || NSApp.windows.contains(w) { return }
        mainWindow = nil  // clear stale ref
        if let window = NSApp.windows.first(where: { $0.title == "thinkur" }) {
            window.delegate = self
            mainWindow = window
        }
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
        captureMainWindow()

        if let window = mainWindow {
            window.delegate = self  // Re-assert in case SwiftUI reset it
            if window.isVisible && window.isKeyWindow {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            // Window was destroyed by SwiftUI — activate to trigger recreation
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mainWindow = nil  // Clear stale ref so captureMainWindow re-searches
                self?.captureMainWindow()
                self?.mainWindow?.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        telemetryService?.sendPendingDigest()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Menu bar app — stay running when window closes
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)  // Hide, don't destroy
        return false
    }

    // MARK: - Menu Bar Icon

    /// Draws a 3×3 grid of rounded squares matching the app icon.
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            let gridCount = 3
            let squareSize: CGFloat = 4.0
            let gap: CGFloat = 1.5
            let pitch = squareSize + gap

            let totalSpan = CGFloat(gridCount) * squareSize + CGFloat(gridCount - 1) * gap
            let origin = (bounds.width - totalSpan) / 2

            NSColor.black.setFill()
            let radius: CGFloat = 0.8

            for row in 0..<gridCount {
                for col in 0..<gridCount {
                    let x = origin + CGFloat(col) * pitch
                    let y = origin + CGFloat(row) * pitch
                    let rect = NSRect(x: x, y: y, width: squareSize, height: squareSize)
                    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
