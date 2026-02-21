import Cocoa
import os

@MainActor
@Observable
final class FrontmostAppDetector {
    var bundleID: String = ""
    var appName: String = ""

    @ObservationIgnored
    private var observer: NSObjectProtocol?

    init() {
        updateCurrentApp()
    }

    func startObserving() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            let bundleID = app.bundleIdentifier ?? ""
            let appName = app.localizedName ?? ""
            Task { @MainActor in
                self?.bundleID = bundleID
                self?.appName = appName
                Logger.app.debug("Frontmost app changed")
            }
        }
        Logger.app.info("Frontmost app detector started")
    }

    func stopObserving() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func updateCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        bundleID = app.bundleIdentifier ?? ""
        appName = app.localizedName ?? ""
    }
}
