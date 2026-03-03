/// Global hotkey manager using Carbon RegisterEventHotKey via KeyboardShortcuts.
///
/// Registers a system-wide hotkey that fires onKeyDown/onKeyUp callbacks.
/// Carbon hotkeys are matched by the WindowServer — no CGEvent tap, no background
/// thread, no Input Monitoring permission needed. When thinkur is frontmost the
/// shortcut is disabled so TextFields and Tab navigation work without interference.

import Cocoa
import KeyboardShortcuts
import os

final class HotkeyManager: HotkeyListening {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private(set) var isRunning = false
    private var frontmostObserver: NSObjectProtocol?
    private var reEnableWork: DispatchWorkItem?
    private var isSelfFrontmost = false
    private let selfPID = ProcessInfo.processInfo.processIdentifier

    func start() -> Bool {
        guard !isRunning else { return true }

        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.onKeyDown?()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.onKeyUp?()
        }

        // Check initial state
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == selfPID
        isSelfFrontmost = frontmost
        if frontmost {
            KeyboardShortcuts.disable(.toggleRecording)
        } else {
            KeyboardShortcuts.enable(.toggleRecording)
        }

        // Single observer for all app activations — avoids the repeated
        // didBecomeActiveNotification spam from ViewBridge bounces on macOS 26.
        frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isRunning,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            let nowFrontmost = (app.processIdentifier == self.selfPID)

            // Skip if state hasn't changed
            guard nowFrontmost != self.isSelfFrontmost else { return }
            self.isSelfFrontmost = nowFrontmost

            if nowFrontmost {
                self.reEnableWork?.cancel()
                self.reEnableWork = nil
                KeyboardShortcuts.disable(.toggleRecording)
                Logger.hotkey.debug("thinkur activated — shortcut disabled")
            } else {
                // Debounce: ViewBridge crashes on macOS 26 cause momentary focus
                // loss that bounces back almost immediately.
                self.reEnableWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.isRunning, !self.isSelfFrontmost else { return }
                    KeyboardShortcuts.enable(.toggleRecording)
                    Logger.hotkey.debug("Shortcut re-enabled after debounce")
                }
                self.reEnableWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
        }

        isRunning = true
        Logger.hotkey.info("Hotkey manager started (KeyboardShortcuts/Carbon)")
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        reEnableWork?.cancel()
        reEnableWork = nil

        KeyboardShortcuts.disable(.toggleRecording)

        if let obs = frontmostObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        frontmostObserver = nil

        onKeyDown = nil
        onKeyUp = nil
        Logger.hotkey.info("Hotkey manager stopped")
    }

    deinit {
        stop()
    }
}
