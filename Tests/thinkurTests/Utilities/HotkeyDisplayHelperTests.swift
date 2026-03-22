import Testing
import Cocoa
@testable import thinkur

@Suite("HotkeyDisplayHelper")
struct HotkeyDisplayHelperTests {
    @Test func keyNameReturnsTabForKeyCode48() {
        #expect(HotkeyDisplayHelper.keyName(for: 48) == "Tab")
    }

    @Test func keyNameReturnsSpaceForKeyCode49() {
        #expect(HotkeyDisplayHelper.keyName(for: 49) == "Space")
    }

    @Test func keyNameReturnsLetterForLetterKeyCodes() {
        #expect(HotkeyDisplayHelper.keyName(for: 0) == "A")
        #expect(HotkeyDisplayHelper.keyName(for: 1) == "S")
        #expect(HotkeyDisplayHelper.keyName(for: 45) == "N")
    }

    @Test func keyNameReturnsKeyNForUnknownKeyCode() {
        #expect(HotkeyDisplayHelper.keyName(for: 200) == "Key 200")
    }

    @Test func modifierSymbolsIncludesCorrectSymbols() {
        #expect(HotkeyDisplayHelper.modifierSymbols(for: .control) == "\u{2303}")
        #expect(HotkeyDisplayHelper.modifierSymbols(for: .option) == "\u{2325}")
        #expect(HotkeyDisplayHelper.modifierSymbols(for: .shift) == "\u{21E7}")
        #expect(HotkeyDisplayHelper.modifierSymbols(for: .command) == "\u{2318}")
        let combined: NSEvent.ModifierFlags = [.control, .command]
        #expect(HotkeyDisplayHelper.modifierSymbols(for: combined) == "\u{2303}\u{2318}")
    }

    @Test func displayNameCombinesModifiersAndKey() {
        let result = HotkeyDisplayHelper.displayName(keyCode: 49, modifiers: .command)
        #expect(result == "\u{2318}Space")
    }

    @Test func displayNameWithNoModifiersReturnsKeyOnly() {
        let result = HotkeyDisplayHelper.displayName(keyCode: 48, modifiers: [])
        #expect(result == "Tab")
    }
}
