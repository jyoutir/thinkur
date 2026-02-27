import Cocoa
import os

final class HotkeyManager: HotkeyListening {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelf: Unmanaged<HotkeyManager>?
    private var isKeyDown = false
    private var healthTimer: Timer?

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
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isRunning = true
        startHealthMonitor()
        Logger.hotkey.info("Hotkey manager started — listening for Tab key")
        return true
    }

    func stop() {
        guard isRunning else { return }

        stopHealthMonitor()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        isKeyDown = false
        // Release the retained self after the tap is fully torn down
        retainedSelf?.release()
        retainedSelf = nil
        Logger.hotkey.info("Hotkey manager stopped")
    }

    private func startHealthMonitor() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                Logger.hotkey.warning("Event tap was silently disabled — re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
    }

    private func stopHealthMonitor() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if system disabled it due to slow processing
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
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
