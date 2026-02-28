import Cocoa
import os

final class HotkeyManager: HotkeyListening {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelf: Unmanaged<HotkeyManager>?
    private var isKeyDown = false
    private var healthTimer: DispatchSourceTimer?
    private var tapDisableCount = 0

    /// Dedicated high-priority queue for the event tap's CFRunLoop.
    /// Keeps event processing off the main thread so SwiftUI work can't stall system events.
    private let tapQueue = DispatchQueue(label: "com.thinkur.hotkey-tap", qos: .userInteractive)
    private var tapRunLoop: CFRunLoop?

    /// When thinkur is frontmost, the tap is fully disabled so keyboard events
    /// bypass it entirely. This ensures TextFields, Tab navigation, and Input Methods
    /// work without interference from the active event tap.
    private var isSelfFrontmost = false
    private let selfPID = ProcessInfo.processInfo.processIdentifier
    private var frontmostObserver: NSObjectProtocol?

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    var targetKeyCode: UInt16 = Constants.tabKeyCode
    var targetModifiers: CGEventFlags = []

    private(set) var isRunning = false

    func start() -> Bool {
        guard !isRunning else { return true }

        let trusted = AXIsProcessTrusted()
        let listenAccess = CGPreflightListenEventAccess()
        Logger.hotkey.info("AXIsProcessTrusted: \(trusted), CGPreflightListenEventAccess: \(listenAccess)")

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        // Retain self for the event tap callback to prevent use-after-free.
        // Released in stop() before the tap is destroyed.
        let retained = Unmanaged.passRetained(self)
        retainedSelf = retained
        let refcon = retained.toOpaque()

        // Create tap on the calling thread (needs main thread for permission checks)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: refcon
        )

        guard let eventTap else {
            Logger.hotkey.error("Failed to create event tap — AXIsProcessTrusted=\(trusted), listenAccess=\(listenAccess)")
            retainedSelf?.release()
            retainedSelf = nil
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        // Run the event tap on a dedicated thread so main thread congestion
        // (SwiftUI view updates, TextField focus changes) can't stall system event delivery.
        tapQueue.async { [weak self] in
            guard let self, let source = self.runLoopSource else { return }
            let rl = CFRunLoopGetCurrent()
            self.tapRunLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()
            // CFRunLoopRun returns after CFRunLoopStop is called in stop()
        }

        isRunning = true
        tapDisableCount = 0
        startHealthMonitor()
        startObservingFrontmostApp()
        Logger.hotkey.info("Hotkey manager started — listening for key \(self.targetKeyCode)")
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        isKeyDown = false

        stopHealthMonitor()
        stopObservingFrontmostApp()

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        // Stop the dedicated run loop so the tapQueue thread exits
        if let rl = tapRunLoop {
            CFRunLoopStop(rl)
        }

        // Wait for the tap thread to finish before cleaning up refs
        tapQueue.sync {}

        if let runLoopSource, let rl = tapRunLoop {
            CFRunLoopRemoveSource(rl, runLoopSource, .commonModes)
        }

        tapRunLoop = nil
        eventTap = nil
        runLoopSource = nil

        // Release the retained self after the tap is fully torn down
        retainedSelf?.release()
        retainedSelf = nil
        Logger.hotkey.info("Hotkey manager stopped")
    }

    // MARK: - Health Monitor

    private func startHealthMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self, let tap = self.eventTap, self.isRunning else { return }

            // Don't re-enable tap when we intentionally disabled it (thinkur is frontmost)
            guard !self.isSelfFrontmost else { return }

            if !CGEvent.tapIsEnabled(tap: tap) {
                self.tapDisableCount += 1
                Logger.hotkey.warning("Event tap disabled by system (count: \(self.tapDisableCount))")

                if self.tapDisableCount >= 3 {
                    // Nuclear recovery: tear down and recreate
                    Logger.hotkey.error("Event tap disabled 3 times — recreating tap")
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.stop()
                        _ = self.start()
                    }
                } else {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } else {
                // Reset counter on successful check
                self.tapDisableCount = 0
            }
        }
        timer.resume()
        healthTimer = timer
    }

    private func stopHealthMonitor() {
        healthTimer?.cancel()
        healthTimer = nil
    }

    // MARK: - Frontmost App Tracking

    /// Disables the event tap when thinkur is active so keyboard events bypass it
    /// entirely — no interference with TextFields, Tab navigation, or Input Methods.
    /// Re-enables the tap when another app takes focus so the hotkey works.
    private func startObservingFrontmostApp() {
        let selfFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == selfPID
        isSelfFrontmost = selfFrontmost
        if selfFrontmost, let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self,
                  let tap = self.eventTap,
                  self.isRunning,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            let nowFrontmost = (app.processIdentifier == self.selfPID)
            self.isSelfFrontmost = nowFrontmost

            if nowFrontmost {
                // Disable tap completely — events bypass it, TextFields work normally
                CGEvent.tapEnable(tap: tap, enable: false)
                Logger.hotkey.debug("thinkur activated — tap disabled")
            } else {
                // Re-enable tap — hotkey works in other apps
                CGEvent.tapEnable(tap: tap, enable: true)
                self.tapDisableCount = 0
                Logger.hotkey.debug("Other app activated — tap enabled")
            }
        }
    }

    private func stopObservingFrontmostApp() {
        if let frontmostObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(frontmostObserver)
        }
        frontmostObserver = nil
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If the system disabled our tap, just pass the event through.
        // The health monitor will handle re-enabling or recreating.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            return Unmanaged.passRetained(event)
        }

        // Safety: if somehow called while thinkur is frontmost, pass through
        if isSelfFrontmost {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard keyCode == Int64(targetKeyCode) else {
            return Unmanaged.passRetained(event)
        }

        // Handle Fn/Globe key — it only generates flagsChanged, not keyDown/keyUp
        if type == .flagsChanged && targetKeyCode == 63 {
            let fnDown = event.flags.contains(.maskSecondaryFn)
            if fnDown && !isKeyDown {
                isKeyDown = true
                onKeyDown?()
                return nil
            } else if !fnDown && isKeyDown {
                isKeyDown = false
                onKeyUp?()
                return nil
            }
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            // Already activated — suppress repeats regardless of modifier state
            // (user may have released a modifier while still holding the key)
            if isKeyDown {
                return nil
            }

            // Strict modifier matching only on initial activation
            let standardFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            let currentModifiers = event.flags.intersection(standardFlags)
            guard currentModifiers == targetModifiers else {
                return Unmanaged.passRetained(event)
            }

            // Ignore key repeat events
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat)
            if isRepeat != 0 {
                return nil
            }

            isKeyDown = true
            onKeyDown?()
            return nil
        } else if type == .keyUp {
            // Lenient on release — always handle if we're in activated state,
            // even if modifiers changed since keyDown (e.g. user released Shift before S)
            if isKeyDown {
                isKeyDown = false
                onKeyUp?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    deinit {
        stop()
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}
