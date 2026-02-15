protocol HotkeyListening: AnyObject {
    var onKeyDown: (() -> Void)? { get set }
    var onKeyUp: (() -> Void)? { get set }
    var isRunning: Bool { get }
    func start() -> Bool
    func stop()
}
