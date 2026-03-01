/// Global hotkey manager using Carbon RegisterEventHotKey.
///
/// Carbon hotkeys fire only on the exact registered key combo — no manual filtering needed.
/// Supports both keyDown (kEventHotKeyPressed) and keyUp (kEventHotKeyReleased) for push-to-talk.
///
/// When thinkur is frontmost, the hotkey is unregistered so keyboard events pass through to
/// TextFields normally. When another app takes focus, the hotkey re-registers after a 500ms
/// debounce (to absorb ViewBridge bounces on macOS 26).
///
/// Fn/Globe key (keyCode 63) uses a minimal CGEvent tap fallback since Carbon can't register
/// modifier-only keys.

import Carbon
import Cocoa
import os

final class HotkeyManager: HotkeyListening {
    // MARK: - Carbon Hotkey State

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    // MARK: - Fn/Globe Key Fallback (CGEvent tap)

    private var fnEventTap: CFMachPort?
    private var fnRunLoopSource: CFRunLoopSource?
    private var fnRetainedSelf: Unmanaged<HotkeyManager>?
    private let fnTapQueue = DispatchQueue(label: "com.thinkur.fn-tap", qos: .userInteractive)
    private var fnTapRunLoop: CFRunLoop?

    // MARK: - Shared State

    private var isKeyDown = false
    private var isSelfFrontmost = false
    private let selfPID = ProcessInfo.processInfo.processIdentifier
    private var frontmostObserver: NSObjectProtocol?
    private var reRegisterWork: DispatchWorkItem?

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    var targetKeyCode: UInt16 = Constants.tabKeyCode
    var targetModifiers: CGEventFlags = []

    /// Injected check for whether the app window is visible.
    /// Used during hotkey re-register debounce to detect spurious focus loss.
    var isAppWindowVisible: (() -> Bool)?

    private(set) var isRunning = false

    // MARK: - Public API

    func start() -> Bool {
        guard !isRunning else { return true }

        let trusted = AXIsProcessTrusted()
        let listenAccess = CGPreflightListenEventAccess()
        Logger.hotkey.info("AXIsProcessTrusted: \(trusted), CGPreflightListenEventAccess: \(listenAccess)")

        let success: Bool
        if targetKeyCode == 63 {
            success = startFnKeyTap()
        } else {
            success = startCarbonHotkey()
        }

        guard success else { return false }

        isRunning = true
        startObservingFrontmostApp()
        Logger.hotkey.info("Hotkey manager started — listening for key \(self.targetKeyCode)")
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        isKeyDown = false

        stopObservingFrontmostApp()
        reRegisterWork?.cancel()
        reRegisterWork = nil

        if targetKeyCode == 63 {
            stopFnKeyTap()
        } else {
            stopCarbonHotkey()
        }

        Logger.hotkey.info("Hotkey manager stopped")
    }

    // MARK: - Carbon Hotkey Registration

    private func startCarbonHotkey() -> Bool {
        installCarbonHandler()
        return registerHotkey()
    }

    private func stopCarbonHotkey() {
        unregisterHotkey()
        removeCarbonHandler()
    }

    private func installCarbonHandler() {
        guard handlerRef == nil else { return }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            carbonHotkeyHandler,
            eventTypes.count,
            &eventTypes,
            refcon,
            &handlerRef
        )
    }

    private func removeCarbonHandler() {
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
    }

    @discardableResult
    private func registerHotkey() -> Bool {
        guard hotKeyRef == nil else { return true }

        let carbonMods = Self.cgEventFlagsToCarbonModifiers(targetModifiers)
        var hotKeyID = EventHotKeyID(
            signature: Self.fourCharCode("thkr"),
            id: 1
        )

        let status = RegisterEventHotKey(
            UInt32(targetKeyCode),
            carbonMods,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            Logger.hotkey.error("RegisterEventHotKey failed: \(status)")
            return false
        }

        Logger.hotkey.debug("Registered hotkey: keyCode=\(self.targetKeyCode), carbonMods=\(carbonMods)")
        return true
    }

    private func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            Logger.hotkey.debug("Unregistered hotkey")
        }
    }

    // MARK: - Carbon Event Handling

    func handleCarbonEvent(_ event: EventRef) {
        var hotKeyID = EventHotKeyID()
        GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        let kind = Int(GetEventKind(event))

        if kind == kEventHotKeyPressed {
            guard !isKeyDown else { return }
            isKeyDown = true
            onKeyDown?()
        } else if kind == kEventHotKeyReleased {
            guard isKeyDown else { return }
            isKeyDown = false
            onKeyUp?()
        }
    }

    // MARK: - Fn/Globe Key Fallback

    private func startFnKeyTap() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let retained = Unmanaged.passRetained(self)
        fnRetainedSelf = retained
        let refcon = retained.toOpaque()

        fnEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: fnKeyCallback,
            userInfo: refcon
        )

        guard let tap = fnEventTap else {
            Logger.hotkey.error("Failed to create Fn key event tap")
            fnRetainedSelf?.release()
            fnRetainedSelf = nil
            return false
        }

        fnRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        fnTapQueue.async { [weak self] in
            guard let self, let source = self.fnRunLoopSource else { return }
            let rl = CFRunLoopGetCurrent()
            self.fnTapRunLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }

        return true
    }

    private func stopFnKeyTap() {
        if let tap = fnEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = fnTapRunLoop {
            CFRunLoopStop(rl)
        }
        fnTapQueue.sync {}
        if let source = fnRunLoopSource, let rl = fnTapRunLoop {
            CFRunLoopRemoveSource(rl, source, .commonModes)
        }
        fnTapRunLoop = nil
        fnEventTap = nil
        fnRunLoopSource = nil
        fnRetainedSelf?.release()
        fnRetainedSelf = nil
    }

    func handleFnEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = fnEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard isSelfFrontmost == false else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 63 else {
            return Unmanaged.passRetained(event)
        }

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

    // MARK: - Frontmost App Tracking

    /// When thinkur is frontmost, unregister the hotkey so keyboard events pass through
    /// to TextFields normally. Re-register when another app takes focus.
    private func startObservingFrontmostApp() {
        let selfFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == selfPID
        isSelfFrontmost = selfFrontmost
        if selfFrontmost {
            if targetKeyCode == 63 {
                if let tap = fnEventTap { CGEvent.tapEnable(tap: tap, enable: false) }
            } else {
                unregisterHotkey()
            }
        }

        frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self, self.isRunning,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            let nowFrontmost = (app.processIdentifier == self.selfPID)
            self.isSelfFrontmost = nowFrontmost

            if nowFrontmost {
                self.reRegisterWork?.cancel()
                self.reRegisterWork = nil
                if self.targetKeyCode == 63 {
                    if let tap = self.fnEventTap { CGEvent.tapEnable(tap: tap, enable: false) }
                } else {
                    self.unregisterHotkey()
                }
                Logger.hotkey.debug("thinkur activated — hotkey unregistered")
            } else {
                // Debounce re-register: ViewBridge crashes on macOS 26 cause
                // momentary focus loss that bounces back almost immediately.
                self.reRegisterWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.isRunning, !self.isSelfFrontmost else { return }

                    // If the thinkur window is still visible, this was a spurious
                    // focus loss (e.g. ViewBridge crash). Reactivate instead of
                    // re-registering the hotkey so TextFields keep working.
                    let thinkurWindowVisible = self.isAppWindowVisible?() ?? NSApp.windows.contains {
                        $0.identifier?.rawValue.contains("main") == true && $0.isVisible
                    }
                    if thinkurWindowVisible {
                        NSApp.activate(ignoringOtherApps: true)
                        Logger.hotkey.debug("Window still visible — reactivating app instead of re-registering hotkey")
                        return
                    }

                    if self.targetKeyCode == 63 {
                        if let tap = self.fnEventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    } else {
                        self.registerHotkey()
                    }
                    Logger.hotkey.debug("Hotkey re-registered after debounce")
                }
                self.reRegisterWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
                Logger.hotkey.debug("Other app activated — hotkey re-register scheduled")
            }
        }
    }

    private func stopObservingFrontmostApp() {
        if let frontmostObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(frontmostObserver)
        }
        frontmostObserver = nil
    }

    // MARK: - Modifier Conversion

    /// Convert CGEventFlags (same raw values as NSEvent.ModifierFlags) to Carbon modifier mask.
    /// NSEvent/CGEvent and Carbon use completely different bit positions:
    ///   Command: 0x100000 (NSEvent) → 0x0100 (cmdKey)
    ///   Shift:   0x020000 (NSEvent) → 0x0200 (shiftKey)
    ///   Option:  0x080000 (NSEvent) → 0x0800 (optionKey)
    ///   Control: 0x040000 (NSEvent) → 0x1000 (controlKey)
    static func cgEventFlagsToCarbonModifiers(_ flags: CGEventFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.maskCommand)   { carbon |= UInt32(cmdKey) }
        if flags.contains(.maskShift)     { carbon |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { carbon |= UInt32(optionKey) }
        if flags.contains(.maskControl)   { carbon |= UInt32(controlKey) }
        return carbon
    }

    /// Create a four-character code from a string (e.g., "thkr" → OSType).
    static func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) | OSType(char)
        }
        return result
    }

    deinit {
        stop()
    }
}

// MARK: - Carbon Event Handler (C function)

private func carbonHotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleCarbonEvent(event)
    return noErr
}

// MARK: - Fn Key CGEvent Callback (C function)

private func fnKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleFnEvent(type: type, event: event)
}
