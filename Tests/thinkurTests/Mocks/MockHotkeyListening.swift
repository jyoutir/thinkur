import CoreGraphics
import Foundation
@testable import thinkur

final class MockHotkeyListening: HotkeyListening {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    var isRunning = false
    private(set) var configuredKeyCode: UInt16?
    private(set) var configuredModifiers: CGEventFlags?

    func configure(keyCode: UInt16, modifiers: CGEventFlags) {
        configuredKeyCode = keyCode
        configuredModifiers = modifiers
    }

    func start() -> Bool {
        isRunning = true
        return true
    }

    func stop() {
        isRunning = false
    }
}
