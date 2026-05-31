import Cocoa
import Combine

@MainActor
final class HotkeyRecordingSession: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var currentModifiers: NSEvent.ModifierFlags = []

    private var eventMonitor: Any?
    private static let standardModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    var recordingLabel: String {
        let mods = HotkeyDisplayHelper.modifierSymbols(for: currentModifiers)
        if mods.isEmpty {
            return "Press key"
        }
        return "\(mods) key"
    }

    func startRecording(onCommit: @escaping (HotkeyBinding) -> Void) {
        stopRecording()
        isRecording = true

        // Flush stale events from keyboard-activating the button before recording.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.isRecording, self.eventMonitor == nil else { return }
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                guard let self else { return event }

                if event.type == .flagsChanged {
                    if event.keyCode == Constants.fnKeyCode {
                        onCommit(HotkeyBinding(keyCode: Constants.fnKeyCode, modifiers: 0))
                        self.stopRecording()
                        return nil
                    }
                    self.currentModifiers = event.modifierFlags.intersection(Self.standardModifiers)
                    return event
                }

                if event.keyCode == Constants.escapeKeyCode {
                    self.stopRecording()
                    return nil
                }

                let modifiers = event.modifierFlags.intersection(Self.standardModifiers)
                onCommit(HotkeyBinding(keyCode: event.keyCode, modifiers: UInt(modifiers.rawValue)))
                self.stopRecording()
                return nil
            }
        }
    }

    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        currentModifiers = []
        isRecording = false
    }

    func toggleRecording(onCommit: @escaping (HotkeyBinding) -> Void) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(onCommit: onCommit)
        }
    }

    func selectShortcutOption(
        _ option: HotkeyShortcutOption,
        applySelection: (HotkeyShortcutOption) -> Void,
        onCustomCommit: @escaping (HotkeyBinding) -> Void
    ) {
        stopRecording()
        applySelection(option)

        if option == .custom {
            startRecording(onCommit: onCustomCommit)
        }
    }
}
