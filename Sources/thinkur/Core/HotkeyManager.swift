import Cocoa
import os

final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isKeyDown = false

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

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

        let refcon = Unmanaged.passUnretained(self).toOpaque()

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
        Logger.hotkey.info("Hotkey manager started — listening for Tab key")
        return true
    }

    func stop() {
        guard isRunning else { return }

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
        Logger.hotkey.info("Hotkey manager stopped")
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

        // Only handle Tab key (keycode 48)
        guard keyCode == Int64(Constants.tabKeyCode) else {
            return Unmanaged.passRetained(event)
        }

        // Ignore if any modifier keys are held (allow Cmd+Tab, Option+Tab, etc.)
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskAlternate) ||
           flags.contains(.maskControl) || flags.contains(.maskShift) {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            // Ignore key repeat events
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat)
            if isRepeat != 0 {
                return nil // Suppress repeat but don't re-trigger
            }

            if !isKeyDown {
                isKeyDown = true
                onKeyDown?()
            }
            return nil // Suppress the Tab key
        } else if type == .keyUp {
            if isKeyDown {
                isKeyDown = false
                onKeyUp?()
            }
            return nil // Suppress the Tab key
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
