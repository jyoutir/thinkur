import Cocoa
import os

@MainActor
final class FrontmostAppDetector: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""

    private var observer: NSObjectProtocol?

    init() {
        // Read initial state
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
            self?.bundleID = app.bundleIdentifier ?? ""
            self?.appName = app.localizedName ?? ""
            Logger.app.info("Frontmost app: \(self?.appName ?? "") (\(self?.bundleID ?? ""))")
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

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
