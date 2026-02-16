import Foundation
@testable import thinkur

final class MockHotkeyListening: HotkeyListening {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    var isRunning = false

    func start() -> Bool {
        isRunning = true
        return true
    }

    func stop() {
        isRunning = false
    }
}
