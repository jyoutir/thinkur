/// Global hotkey manager using Carbon RegisterEventHotKey.
///
/// Carbon hotkeys fire only on the exact registered key combo — no manual filtering needed.
/// Uses GetApplicationEventTarget() (not GetEventDispatcherTarget()) for LSUIElement compatibility.
/// Supports both keyDown (kEventHotKeyPressed) and keyUp (kEventHotKeyReleased) for push-to-talk.
///
/// When thinkur is frontmost, the Carbon hotkey is unregistered so keyboard events pass through
/// to TextFields normally. A local NSEvent monitor takes over instead — it fires the hotkey
/// callback unless the key window's first responder is a text input (NSText/NSTextField),
/// so the hotkey still works during onboarding and other non-text-editing screens.
/// When another app takes focus, the global listener resumes and the local monitor is removed.
///
/// Fn/Globe, Right Command, and Right Option use a minimal CGEvent tap fallback since
/// Carbon can't register modifier-only keys.

import Carbon
import Cocoa
import os

private struct ModifierOnlyKey: Equatable {
    let keyCode: UInt16
    private let deviceMask: UInt64

    init?(keyCode: UInt16, modifiers: CGEventFlags) {
        guard modifiers.isEmpty else { return nil }

        switch keyCode {
        case Constants.rightCommandKeyCode:
            self.deviceMask = 0x00000010
        case Constants.rightOptionKeyCode:
            self.deviceMask = 0x00000040
        case Constants.fnKeyCode:
            self.deviceMask = CGEventFlags.maskSecondaryFn.rawValue
        default:
            return nil
        }

        self.keyCode = keyCode
    }

    func isPressed(rawFlags: UInt64) -> Bool {
        rawFlags & deviceMask != 0
    }
}

final class HotkeyManager: HotkeyListening {
    // MARK: - Carbon Hotkey State

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    // MARK: - Modifier-Only Key Fallback (CGEvent tap)

    private var modifierEventTap: CFMachPort?
    private var modifierRunLoopSource: CFRunLoopSource?
    private var modifierRetainedSelf: Unmanaged<HotkeyManager>?
    private let modifierTapQueue = DispatchQueue(label: "com.thinkur.modifier-tap", qos: .userInteractive)
    private var modifierTapRunLoop: CFRunLoop?

    // MARK: - Local Event Monitor (active when thinkur is frontmost)

    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var localModifierMonitor: Any?

    // MARK: - Shared State (thread-safe)

    private let _isKeyDown = OSAllocatedUnfairLock(initialState: false)
    private let _isSelfFrontmost = OSAllocatedUnfairLock(initialState: false)

    private var isKeyDown: Bool {
        get { _isKeyDown.withLock { $0 } }
        set { _isKeyDown.withLock { $0 = newValue } }
    }

    private var isSelfFrontmost: Bool {
        get { _isSelfFrontmost.withLock { $0 } }
        set { _isSelfFrontmost.withLock { $0 = newValue } }
    }

    private let selfPID = ProcessInfo.processInfo.processIdentifier
    private var frontmostObserver: NSObjectProtocol?

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    private(set) var targetKeyCode: UInt16 = Constants.tabKeyCode
    private(set) var targetModifiers: CGEventFlags = []

    private(set) var isRunning = false

    private var modifierOnlyKey: ModifierOnlyKey? {
        ModifierOnlyKey(keyCode: targetKeyCode, modifiers: targetModifiers)
    }

    // MARK: - Public API

    func configure(keyCode: UInt16, modifiers: CGEventFlags) {
        targetKeyCode = keyCode
        targetModifiers = modifiers
    }

    func start() -> Bool {
        guard !isRunning else {
            Logger.hotkey.debug("start() called but already running")
            return true
        }

        let trusted = AXIsProcessTrusted()
        let listenAccess = CGPreflightListenEventAccess()
        Logger.hotkey.info("start() — AXIsProcessTrusted: \(trusted), CGPreflightListenEventAccess: \(listenAccess)")
        Logger.hotkey.info("start() — targetKeyCode=\(self.targetKeyCode), targetModifiers=\(self.targetModifiers.rawValue)")

        let success = startConfiguredBackend()

        guard success else {
            Logger.hotkey.error("start() — FAILED to start hotkey")
            return false
        }

        isRunning = true
        startObservingFrontmostApp()
        Logger.hotkey.info("start() — SUCCESS, listening for key \(self.targetKeyCode), hotKeyRef=\(self.hotKeyRef != nil)")
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        isKeyDown = false

        stopObservingFrontmostApp()

        stopConfiguredBackend()

        Logger.hotkey.info("stop() — Hotkey manager stopped")
    }

    // MARK: - Carbon Hotkey Registration

    private func startConfiguredBackend() -> Bool {
        if modifierOnlyKey != nil {
            return startModifierKeyTap()
        }
        return startCarbonHotkey()
    }

    private func stopConfiguredBackend() {
        if modifierOnlyKey != nil {
            stopModifierKeyTap()
        } else {
            stopCarbonHotkey()
        }
    }

    private func startCarbonHotkey() -> Bool {
        let handlerOK = installCarbonHandler()
        if !handlerOK {
            Logger.hotkey.error("startCarbonHotkey — installCarbonHandler FAILED")
            return false
        }
        return registerHotkey()
    }

    private func stopCarbonHotkey() {
        unregisterHotkey()
        removeCarbonHandler()
    }

    @discardableResult
    private func installCarbonHandler() -> Bool {
        guard handlerRef == nil else {
            Logger.hotkey.debug("installCarbonHandler — handler already installed")
            return true
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            eventTypes.count,
            &eventTypes,
            refcon,
            &handlerRef
        )

        if status != noErr {
            Logger.hotkey.error("InstallEventHandler FAILED: status=\(status)")
            return false
        }

        Logger.hotkey.debug("installCarbonHandler — SUCCESS, handlerRef=\(self.handlerRef != nil)")
        return true
    }

    private func removeCarbonHandler() {
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
            Logger.hotkey.debug("removeCarbonHandler — handler removed")
        }
    }

    @discardableResult
    private func registerHotkey() -> Bool {
        guard hotKeyRef == nil else {
            Logger.hotkey.debug("registerHotkey — already registered, skipping")
            return true
        }

        let carbonMods = Self.cgEventFlagsToCarbonModifiers(targetModifiers)
        let hotKeyID = EventHotKeyID(
            signature: Self.fourCharCode("thkr"),
            id: 1
        )

        Logger.hotkey.info("registerHotkey — keyCode=\(self.targetKeyCode), carbonMods=\(carbonMods), cgFlags=0x\(String(self.targetModifiers.rawValue, radix: 16))")

        let status = RegisterEventHotKey(
            UInt32(targetKeyCode),
            carbonMods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            Logger.hotkey.error("RegisterEventHotKey FAILED: status=\(status)")
            return false
        }

        Logger.hotkey.info("registerHotkey — SUCCESS, hotKeyRef=\(self.hotKeyRef != nil)")
        return true
    }

    private func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            Logger.hotkey.debug("unregisterHotkey — unregistered")
        }
    }

    // MARK: - Carbon Event Handling

    fileprivate func handleCarbonEvent(_ event: EventRef) {
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
        Logger.hotkey.debug("handleCarbonEvent — kind=\(kind), isKeyDown=\(self.isKeyDown), sig=\(hotKeyID.signature), id=\(hotKeyID.id)")

        if kind == kEventHotKeyPressed {
            guard !isKeyDown else {
                Logger.hotkey.debug("handleCarbonEvent — suppressing repeat press")
                return
            }
            isKeyDown = true
            Logger.hotkey.info("HOTKEY PRESSED — firing onKeyDown")
            onKeyDown?()
        } else if kind == kEventHotKeyReleased {
            guard isKeyDown else {
                Logger.hotkey.debug("handleCarbonEvent — release without press, ignoring")
                return
            }
            isKeyDown = false
            Logger.hotkey.info("HOTKEY RELEASED — firing onKeyUp")
            onKeyUp?()
        }
    }

    // MARK: - Modifier-Only Key Fallback

    private func startModifierKeyTap() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let retained = Unmanaged.passRetained(self)
        modifierRetainedSelf = retained
        let refcon = retained.toOpaque()

        modifierEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: modifierKeyCallback,
            userInfo: refcon
        )

        guard let tap = modifierEventTap else {
            Logger.hotkey.error("Failed to create modifier key event tap")
            modifierRetainedSelf?.release()
            modifierRetainedSelf = nil
            return false
        }

        modifierRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        modifierTapQueue.async { [weak self] in
            guard let self, let source = self.modifierRunLoopSource else { return }
            let rl = CFRunLoopGetCurrent()
            self.modifierTapRunLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }

        return true
    }

    private func stopModifierKeyTap() {
        if let tap = modifierEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = modifierTapRunLoop {
            CFRunLoopStop(rl)
        }
        modifierTapQueue.sync {}
        if let source = modifierRunLoopSource, let rl = modifierTapRunLoop {
            CFRunLoopRemoveSource(rl, source, .commonModes)
        }
        modifierTapRunLoop = nil
        modifierEventTap = nil
        modifierRunLoopSource = nil
        modifierRetainedSelf?.release()
        modifierRetainedSelf = nil
    }

    func handleModifierKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            setModifierTapEnabled(true)
            return Unmanaged.passRetained(event)
        }

        guard isSelfFrontmost == false else {
            return Unmanaged.passRetained(event)
        }

        guard let modifierOnlyKey,
              UInt16(event.getIntegerValueField(.keyboardEventKeycode)) == modifierOnlyKey.keyCode
        else {
            return Unmanaged.passRetained(event)
        }

        if handleModifierKeyState(isDown: modifierOnlyKey.isPressed(rawFlags: event.flags.rawValue)) {
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func handleModifierKeyState(isDown: Bool) -> Bool {
        if isDown && !isKeyDown {
            isKeyDown = true
            onKeyDown?()
            return true
        } else if !isDown && isKeyDown {
            isKeyDown = false
            onKeyUp?()
            return true
        }

        return false
    }

    // MARK: - Local Event Monitor (thinkur frontmost)

    /// Install a local NSEvent monitor for keyDown + keyUp so the hotkey works while thinkur
    /// is frontmost. If the key window's first responder is a text input (NSText / NSTextField),
    /// the event passes through so Tab navigation in TextFields still works.
    private func installLocalMonitor() {
        guard localKeyDownMonitor == nil else { return }

        let requiredNSMods = Self.cgEventFlagsToNSModifiers(targetModifiers)

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == self.targetKeyCode,
                  !event.isARepeat,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                      .subtracting([.capsLock, .numericPad, .function]) == requiredNSMods
            else { return event }

            // Let text fields handle the key normally
            if Self.firstResponderIsTextInput { return event }

            guard !self.isKeyDown else { return nil }
            self.isKeyDown = true
            Logger.hotkey.info("LOCAL MONITOR keyDown — firing onKeyDown")
            self.onKeyDown?()
            return nil // swallow event so SwiftUI doesn't see it
        }

        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == self.targetKeyCode,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                      .subtracting([.capsLock, .numericPad, .function]) == requiredNSMods
            else { return event }

            if Self.firstResponderIsTextInput { return event }

            guard self.isKeyDown else { return nil }
            self.isKeyDown = false
            Logger.hotkey.info("LOCAL MONITOR keyUp — firing onKeyUp")
            self.onKeyUp?()
            return nil
        }

        Logger.hotkey.debug("installLocalMonitor — installed")
    }

    /// Install a local monitor for modifier-only hotkeys while thinkur is frontmost.
    /// This mirrors the Carbon local monitor behavior and lets onboarding/testing screens
    /// react to Right Option / Right Command without firing inside text fields.
    private func installLocalModifierMonitor() {
        guard localModifierMonitor == nil else { return }

        localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            guard let modifierOnlyKey = self.modifierOnlyKey,
                  event.keyCode == modifierOnlyKey.keyCode
            else { return event }

            if Self.firstResponderIsTextInput { return event }

            if self.handleModifierKeyState(isDown: modifierOnlyKey.isPressed(rawFlags: UInt64(event.modifierFlags.rawValue))) {
                Logger.hotkey.info("LOCAL MODIFIER — firing hotkey callback")
                return nil
            }

            return event
        }

        Logger.hotkey.debug("installLocalModifierMonitor — installed")
    }

    private func removeLocalMonitor() {
        if let m = localKeyDownMonitor {
            NSEvent.removeMonitor(m)
            localKeyDownMonitor = nil
        }
        if let m = localKeyUpMonitor {
            NSEvent.removeMonitor(m)
            localKeyUpMonitor = nil
        }
        if let m = localModifierMonitor {
            NSEvent.removeMonitor(m)
            localModifierMonitor = nil
        }
        Logger.hotkey.debug("removeLocalMonitor — removed")
    }

    /// Check whether the key window's first responder is a text editing view.
    /// Returns true for NSTextField (field editor), NSTextView, and any NSText subclass.
    private static var firstResponderIsTextInput: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        // The field editor is an NSTextView that appears as first responder when
        // an NSTextField is being edited. Checking for NSText covers both.
        return responder is NSText
    }

    /// Convert CGEventFlags to NSEvent.ModifierFlags for local monitor matching.
    private static func cgEventFlagsToNSModifiers(_ flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var mods: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand)   { mods.insert(.command) }
        if flags.contains(.maskShift)     { mods.insert(.shift) }
        if flags.contains(.maskAlternate) { mods.insert(.option) }
        if flags.contains(.maskControl)   { mods.insert(.control) }
        return mods
    }

    // MARK: - Frontmost App Tracking

    /// When thinkur is frontmost, unregister the Carbon hotkey and install a local NSEvent
    /// monitor instead. The local monitor fires the hotkey unless a text field has focus.
    /// When another app takes focus, the global listener resumes and the local monitor is removed.
    private func startObservingFrontmostApp() {
        let selfFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == selfPID
        isSelfFrontmost = selfFrontmost
        Logger.hotkey.debug("startObservingFrontmostApp — isSelfFrontmost=\(selfFrontmost)")
        if selfFrontmost {
            suspendGlobalHotkeyForFrontmostApp()
        }

        frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isRunning,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            let nowFrontmost = (app.processIdentifier == self.selfPID)
            self.isSelfFrontmost = nowFrontmost

            if nowFrontmost {
                self.suspendGlobalHotkeyForFrontmostApp()
                Logger.hotkey.debug("thinkur activated — global hotkey suspended, local monitor installed")
            } else {
                self.resumeGlobalHotkeyForExternalApp()
                Logger.hotkey.info("Other app (\(app.localizedName ?? "?")) activated — hotkey registered, hotKeyRef=\(self.hotKeyRef != nil)")
            }
        }
    }

    private func suspendGlobalHotkeyForFrontmostApp() {
        if modifierOnlyKey != nil {
            setModifierTapEnabled(false)
            installLocalModifierMonitor()
        } else {
            unregisterHotkey()
            installLocalMonitor()
        }
    }

    private func resumeGlobalHotkeyForExternalApp() {
        removeLocalMonitor()

        if modifierOnlyKey != nil {
            setModifierTapEnabled(true)
        } else {
            registerHotkey()
        }
    }

    private func setModifierTapEnabled(_ enabled: Bool) {
        if let tap = modifierEventTap {
            CGEvent.tapEnable(tap: tap, enable: enabled)
        }
    }

    private func stopObservingFrontmostApp() {
        if let frontmostObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(frontmostObserver)
        }
        frontmostObserver = nil
        removeLocalMonitor()
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
    guard let event, let userData else {
        Logger.hotkey.error("carbonHotkeyHandler — nil event or userData!")
        return OSStatus(eventNotHandledErr)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleCarbonEvent(event)
    return noErr
}

// MARK: - Modifier Key CGEvent Callback (C function)

private func modifierKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleModifierKeyEvent(type: type, event: event)
}
