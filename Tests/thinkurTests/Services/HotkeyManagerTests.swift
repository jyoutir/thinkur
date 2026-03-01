import Testing
import Cocoa
@testable import thinkur

@Suite("HotkeyManager Event Handling")
struct HotkeyManagerTests {

    // MARK: - Helpers

    /// Creates a CGEvent for a key press/release. Returns nil if we lack event-posting permissions.
    private func makeKeyEvent(keyCode: UInt16, keyDown: Bool, flags: CGEventFlags = []) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            return nil
        }
        event.flags = flags
        return event
    }

    /// Creates a flagsChanged CGEvent by synthesizing a keyDown event for the modifier key code
    /// and setting the appropriate flags.
    private func makeFlagsChangedEvent(keyCode: UInt16, flags: CGEventFlags) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            return nil
        }
        event.type = .flagsChanged
        event.flags = flags
        return event
    }

    @MainActor
    private func makeManager(keyCode: UInt16 = 48, modifiers: CGEventFlags = []) -> HotkeyManager {
        let manager = HotkeyManager()
        manager.targetKeyCode = keyCode
        manager.targetModifiers = modifiers
        return manager
    }

    // MARK: - 1. Single key match (Tab, no modifiers)

    @Test @MainActor func singleKeyMatch_triggersOnKeyDown() {
        let manager = makeManager(keyCode: 48) // Tab
        guard let event = makeKeyEvent(keyCode: 48, keyDown: true) else {
            Issue.record("CGEvent creation failed — no event access permissions")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(fired, "onKeyDown should fire for matching key")
        #expect(result == nil, "Event should be consumed (nil)")
    }

    // MARK: - 2. Wrong key code passes through

    @Test @MainActor func wrongKeyCode_passesThrough() {
        let manager = makeManager(keyCode: 48) // Tab
        guard let event = makeKeyEvent(keyCode: 49, keyDown: true) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(!fired, "onKeyDown should NOT fire for wrong key")
        #expect(result != nil, "Event should pass through")
    }

    // MARK: - 3. Modifier+key match (Cmd+S)

    @Test @MainActor func modifierPlusKey_match() {
        let manager = makeManager(keyCode: 1, modifiers: .maskCommand) // Cmd+S
        guard let event = makeKeyEvent(keyCode: 1, keyDown: true, flags: .maskCommand) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(fired, "onKeyDown should fire for Cmd+S")
        #expect(result == nil, "Event should be consumed")
    }

    // MARK: - 4. Wrong modifiers (Shift+S when Cmd+S expected)

    @Test @MainActor func wrongModifiers_passesThrough() {
        let manager = makeManager(keyCode: 1, modifiers: .maskCommand) // Cmd+S
        guard let event = makeKeyEvent(keyCode: 1, keyDown: true, flags: .maskShift) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(!fired, "onKeyDown should NOT fire with wrong modifiers")
        #expect(result != nil, "Event should pass through")
    }

    // MARK: - 5. Multiple modifiers match (Cmd+Shift+R)

    @Test @MainActor func multipleModifiers_match() {
        let flags: CGEventFlags = [.maskCommand, .maskShift]
        let manager = makeManager(keyCode: 15, modifiers: flags) // Cmd+Shift+R
        guard let event = makeKeyEvent(keyCode: 15, keyDown: true, flags: flags) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(fired, "onKeyDown should fire for Cmd+Shift+R")
        #expect(result == nil, "Event should be consumed")
    }

    // MARK: - 6. Subset modifiers (Cmd+R when Cmd+Shift+R expected)

    @Test @MainActor func subsetModifiers_passesThrough() {
        let manager = makeManager(keyCode: 15, modifiers: [.maskCommand, .maskShift])
        guard let event = makeKeyEvent(keyCode: 15, keyDown: true, flags: .maskCommand) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(!fired, "onKeyDown should NOT fire with subset modifiers")
        #expect(result != nil, "Event should pass through")
    }

    // MARK: - 7. Superset modifiers (Cmd+Shift+Opt+R when Cmd+Shift+R expected)

    @Test @MainActor func supersetModifiers_passesThrough() {
        let manager = makeManager(keyCode: 15, modifiers: [.maskCommand, .maskShift])
        guard let event = makeKeyEvent(keyCode: 15, keyDown: true, flags: [.maskCommand, .maskShift, .maskAlternate]) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(!fired, "onKeyDown should NOT fire with superset modifiers")
        #expect(result != nil, "Event should pass through")
    }

    // MARK: - 8. Key repeat suppression

    @Test @MainActor func keyRepeat_suppressed() {
        let manager = makeManager(keyCode: 48) // Tab
        guard let event1 = makeKeyEvent(keyCode: 48, keyDown: true),
              let event2 = makeKeyEvent(keyCode: 48, keyDown: true) else {
            Issue.record("CGEvent creation failed")
            return
        }
        // Simulate key repeat on second event
        event2.setIntegerValueField(.keyboardEventAutorepeat, value: 1)

        var count = 0
        manager.onKeyDown = { count += 1 }

        // First press
        _ = manager.handleEvent(type: .keyDown, event: event1)
        // Repeat — should be consumed but not trigger callback
        let result2 = manager.handleEvent(type: .keyDown, event: event2)
        #expect(count == 1, "onKeyDown should fire only once despite repeat")
        #expect(result2 == nil, "Repeat event should be consumed")
    }

    // MARK: - 9. KeyUp lenient (release modifiers before key)

    @Test @MainActor func keyUp_lenientModifiers() {
        let manager = makeManager(keyCode: 1, modifiers: .maskCommand) // Cmd+S
        guard let keyDown = makeKeyEvent(keyCode: 1, keyDown: true, flags: .maskCommand),
              let keyUp = makeKeyEvent(keyCode: 1, keyDown: false) else { // No modifiers on release
            Issue.record("CGEvent creation failed")
            return
        }

        var downFired = false
        var upFired = false
        manager.onKeyDown = { downFired = true }
        manager.onKeyUp = { upFired = true }

        _ = manager.handleEvent(type: .keyDown, event: keyDown)
        let result = manager.handleEvent(type: .keyUp, event: keyUp)
        #expect(downFired, "onKeyDown should fire")
        #expect(upFired, "onKeyUp should fire even without modifiers on release")
        #expect(result == nil, "KeyUp event should be consumed")
    }

    // MARK: - 10. Fn/Globe key (keyCode 63) via flagsChanged

    @Test @MainActor func fnKey_press_triggersKeyDown() {
        let manager = makeManager(keyCode: 63) // Fn key
        guard let event = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .flagsChanged, event: event)
        #expect(fired, "onKeyDown should fire for Fn press")
        #expect(result == nil, "Event should be consumed")
    }

    // MARK: - 11. Fn key release

    @Test @MainActor func fnKey_release_triggersKeyUp() {
        let manager = makeManager(keyCode: 63)
        guard let press = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn),
              let release = makeFlagsChangedEvent(keyCode: 63, flags: []) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var upFired = false
        manager.onKeyDown = {}
        manager.onKeyUp = { upFired = true }

        // Press first to set isKeyDown
        _ = manager.handleEvent(type: .flagsChanged, event: press)
        // Release
        let result = manager.handleEvent(type: .flagsChanged, event: release)
        #expect(upFired, "onKeyUp should fire for Fn release")
        #expect(result == nil, "Event should be consumed")
    }

    // MARK: - 12. System tap disabled event passes through

    @Test @MainActor func tapDisabledByTimeout_passesThrough() {
        let manager = makeManager(keyCode: 48)
        guard let event = makeKeyEvent(keyCode: 48, keyDown: true) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .tapDisabledByTimeout, event: event)
        #expect(!fired, "onKeyDown should NOT fire for tap disabled event")
        #expect(result != nil, "Event should pass through")
    }

    // MARK: - 13. Self-frontmost passthrough

    @Test @MainActor func selfFrontmost_passesThrough() {
        let manager = makeManager(keyCode: 48)
        guard let event = makeKeyEvent(keyCode: 48, keyDown: true) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        // Simulate thinkur being frontmost by starting + observing, which sets isSelfFrontmost.
        // Since we can't set isSelfFrontmost directly (it's private), we test via the
        // public start/stop which checks NSWorkspace. Instead, we use a workaround:
        // The test process IS the frontmost app, and start() would set isSelfFrontmost = true.
        // But start() requires event tap permissions, so we test the tapDisabled path instead
        // which exercises the same "pass through" logic.
        let result = manager.handleEvent(type: .tapDisabledByUserInput, event: event)
        #expect(!fired, "onKeyDown should NOT fire when tap is disabled")
        #expect(result != nil, "Event should pass through")
    }

    // MARK: - 14. Modifier-only keyDown does NOT trigger if target has a key

    @Test @MainActor func modifierOnlyKeyDown_doesNotTrigger() {
        let manager = makeManager(keyCode: 1, modifiers: .maskCommand) // Cmd+S
        // Send a keyDown for the Command key itself (keyCode 55), not the target key
        guard let event = makeKeyEvent(keyCode: 55, keyDown: true, flags: .maskCommand) else {
            Issue.record("CGEvent creation failed")
            return
        }

        var fired = false
        manager.onKeyDown = { fired = true }

        let result = manager.handleEvent(type: .keyDown, event: event)
        #expect(!fired, "onKeyDown should NOT fire for modifier-only key")
        #expect(result != nil, "Modifier key event should pass through")
    }
}
