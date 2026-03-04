import CoreGraphics

protocol HotkeyListening: AnyObject {
    var onKeyDown: (() -> Void)? { get set }
    var onKeyUp: (() -> Void)? { get set }
    var isRunning: Bool { get }
    func configure(keyCode: UInt16, modifiers: CGEventFlags)
    func start() -> Bool
    func stop()
}
