import Cocoa

enum HotkeyDisplayHelper {
    static func displayName(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let mods = modifierSymbols(for: modifiers)
        let key = keyName(for: keyCode)
        return mods.isEmpty ? key : "\(mods)\(key)"
    }

    static func modifierSymbols(for flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "\u{2303}" }
        if flags.contains(.option) { s += "\u{2325}" }
        if flags.contains(.shift) { s += "\u{21E7}" }
        if flags.contains(.command) { s += "\u{2318}" }
        return s
    }

    static func keyName(for keyCode: UInt16) -> String {
        let specialKeys: [UInt16: String] = [
            48: "Tab", 49: "Space", 36: "Return", 51: "Delete",
            53: "Esc", 76: "Enter", 123: "\u{2190}", 124: "\u{2192}",
            125: "\u{2193}", 126: "\u{2191}", 115: "Home", 119: "End",
            116: "Page Up", 121: "Page Down", 117: "\u{2326}",
            63: "Fn", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        if let name = specialKeys[keyCode] { return name }

        let charKeys: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            50: "`", 10: "\u{00A7}",
        ]
        if let name = charKeys[keyCode] { return name }

        return "Key \(keyCode)"
    }
}
