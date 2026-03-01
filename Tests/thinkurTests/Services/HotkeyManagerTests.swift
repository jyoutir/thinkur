import Testing
import Cocoa
import Carbon
@testable import thinkur

@Suite("HotkeyManager")
struct HotkeyManagerTests {

    // MARK: - Modifier Conversion

    @Suite("Modifier Flag Conversion")
    struct ModifierConversionTests {

        @Test func command_converts() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers(.maskCommand)
            #expect(result == UInt32(cmdKey))
        }

        @Test func shift_converts() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers(.maskShift)
            #expect(result == UInt32(shiftKey))
        }

        @Test func option_converts() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers(.maskAlternate)
            #expect(result == UInt32(optionKey))
        }

        @Test func control_converts() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers(.maskControl)
            #expect(result == UInt32(controlKey))
        }

        @Test func emptyFlags_returnsZero() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers([])
            #expect(result == 0)
        }

        @Test func commandShift_combinesCorrectly() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers([.maskCommand, .maskShift])
            #expect(result == UInt32(cmdKey) | UInt32(shiftKey))
        }

        @Test func allModifiers_combinesCorrectly() {
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers([
                .maskCommand, .maskShift, .maskAlternate, .maskControl
            ])
            let expected = UInt32(cmdKey) | UInt32(shiftKey) | UInt32(optionKey) | UInt32(controlKey)
            #expect(result == expected)
        }

        @Test func nonStandardFlags_ignored() {
            // maskSecondaryFn, maskNumericPad, etc. should not produce Carbon modifiers
            let result = HotkeyManager.cgEventFlagsToCarbonModifiers(.maskSecondaryFn)
            #expect(result == 0)
        }
    }

    // MARK: - FourCharCode

    @Suite("FourCharCode")
    struct FourCharCodeTests {

        @Test func thkr_producesExpectedValue() {
            let code = HotkeyManager.fourCharCode("thkr")
            // 't' = 0x74, 'h' = 0x68, 'k' = 0x6B, 'r' = 0x72
            let expected: OSType = (0x74 << 24) | (0x68 << 16) | (0x6B << 8) | 0x72
            #expect(code == expected)
        }

        @Test func truncatesToFourChars() {
            let long = HotkeyManager.fourCharCode("thinkur")
            let short = HotkeyManager.fourCharCode("thin")
            #expect(long == short)
        }
    }

    // MARK: - Lifecycle

    @Suite("Start/Stop Lifecycle")
    struct LifecycleTests {

        @Test @MainActor func initialState_notRunning() {
            let manager = HotkeyManager()
            #expect(!manager.isRunning)
        }

        @Test @MainActor func stop_whenNotRunning_isNoop() {
            let manager = HotkeyManager()
            manager.stop() // Should not crash
            #expect(!manager.isRunning)
        }

        @Test @MainActor func doubleStop_isNoop() {
            let manager = HotkeyManager()
            // Even if start fails (no permissions in test), stop should be safe
            _ = manager.start()
            manager.stop()
            manager.stop() // Should not crash
            #expect(!manager.isRunning)
        }

        @Test @MainActor func targetKeyCode_defaultsToTab() {
            let manager = HotkeyManager()
            #expect(manager.targetKeyCode == Constants.tabKeyCode)
        }

        @Test @MainActor func targetModifiers_defaultsToEmpty() {
            let manager = HotkeyManager()
            #expect(manager.targetModifiers == [])
        }
    }

    // MARK: - Fn/Globe Key (still uses CGEvent tap)

    @Suite("Fn/Globe Key Event Handling")
    struct FnKeyTests {

        private func makeFlagsChangedEvent(keyCode: UInt16, flags: CGEventFlags) -> CGEvent? {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
                return nil
            }
            event.type = .flagsChanged
            event.flags = flags
            return event
        }

        @Test @MainActor func fnPress_triggersKeyDown() {
            let manager = HotkeyManager()
            manager.targetKeyCode = 63
            guard let event = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn) else {
                Issue.record("CGEvent creation failed — no event access permissions")
                return
            }

            var fired = false
            manager.onKeyDown = { fired = true }

            let result = manager.handleFnEvent(type: .flagsChanged, event: event)
            #expect(fired, "onKeyDown should fire for Fn press")
            #expect(result == nil, "Event should be consumed")
        }

        @Test @MainActor func fnRelease_triggersKeyUp() {
            let manager = HotkeyManager()
            manager.targetKeyCode = 63
            guard let press = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn),
                  let release = makeFlagsChangedEvent(keyCode: 63, flags: []) else {
                Issue.record("CGEvent creation failed")
                return
            }

            var upFired = false
            manager.onKeyDown = {}
            manager.onKeyUp = { upFired = true }

            _ = manager.handleFnEvent(type: .flagsChanged, event: press)
            let result = manager.handleFnEvent(type: .flagsChanged, event: release)
            #expect(upFired, "onKeyUp should fire for Fn release")
            #expect(result == nil, "Event should be consumed")
        }

        @Test @MainActor func wrongKeyCode_passesThrough() {
            let manager = HotkeyManager()
            manager.targetKeyCode = 63
            guard let event = makeFlagsChangedEvent(keyCode: 55, flags: .maskCommand) else {
                Issue.record("CGEvent creation failed")
                return
            }

            var fired = false
            manager.onKeyDown = { fired = true }

            let result = manager.handleFnEvent(type: .flagsChanged, event: event)
            #expect(!fired, "onKeyDown should NOT fire for wrong key")
            #expect(result != nil, "Event should pass through")
        }

        @Test @MainActor func tapDisabledByTimeout_passesThrough() {
            let manager = HotkeyManager()
            manager.targetKeyCode = 63
            guard let event = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn) else {
                Issue.record("CGEvent creation failed")
                return
            }

            var fired = false
            manager.onKeyDown = { fired = true }

            let result = manager.handleFnEvent(type: .tapDisabledByTimeout, event: event)
            #expect(!fired, "onKeyDown should NOT fire for tap disabled event")
            #expect(result != nil, "Event should pass through")
        }

        @Test @MainActor func fnDoubleTap_noDoubleKeyDown() {
            let manager = HotkeyManager()
            manager.targetKeyCode = 63
            guard let press1 = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn),
                  let press2 = makeFlagsChangedEvent(keyCode: 63, flags: .maskSecondaryFn) else {
                Issue.record("CGEvent creation failed")
                return
            }

            var count = 0
            manager.onKeyDown = { count += 1 }

            _ = manager.handleFnEvent(type: .flagsChanged, event: press1)
            _ = manager.handleFnEvent(type: .flagsChanged, event: press2)
            #expect(count == 1, "onKeyDown should fire only once without release in between")
        }
    }

    // MARK: - NSEvent ↔ CGEvent Modifier Roundtrip

    @Suite("NSEvent Modifier Storage Roundtrip")
    struct ModifierRoundtripTests {

        @Test func commandShiftR_roundtrips() {
            // Simulate what HotkeySettingsView does: store NSEvent modifiers as UInt
            let nsFlags: NSEvent.ModifierFlags = [.command, .shift]
            let stored = UInt(nsFlags.rawValue)

            // Simulate what RecordingViewModel does: convert stored UInt → CGEventFlags
            let cgFlags = CGEventFlags(rawValue: UInt64(stored))

            // Simulate what HotkeyManager does: convert CGEventFlags → Carbon
            let carbon = HotkeyManager.cgEventFlagsToCarbonModifiers(cgFlags)

            #expect(carbon == UInt32(cmdKey) | UInt32(shiftKey))
        }

        @Test func noModifiers_roundtrips() {
            let stored: UInt = 0
            let cgFlags = CGEventFlags(rawValue: UInt64(stored))
            let carbon = HotkeyManager.cgEventFlagsToCarbonModifiers(cgFlags)
            #expect(carbon == 0)
        }

        @Test func allFourModifiers_roundtrip() {
            let nsFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let stored = UInt(nsFlags.rawValue)
            let cgFlags = CGEventFlags(rawValue: UInt64(stored))
            let carbon = HotkeyManager.cgEventFlagsToCarbonModifiers(cgFlags)
            let expected = UInt32(cmdKey) | UInt32(shiftKey) | UInt32(optionKey) | UInt32(controlKey)
            #expect(carbon == expected)
        }
    }
}
