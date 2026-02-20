import SwiftUI
import Cocoa

struct HotkeySettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator
    @State private var appeared = false
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Configure the keyboard shortcut for voice typing.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Activation") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "keyboard", title: "Record Shortcut") {
                            Button {
                                startRecording()
                            } label: {
                                KeyboardShortcutBadge(
                                    key: isRecording ? "Press a key\u{2026}" : keyName(for: settings.hotkeyCode)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()

                        ToggleRow(
                            icon: "hand.tap",
                            title: "Hold Mode",
                            subtitle: "Hold key to record, release to stop",
                            isOn: $s.hotkeyHoldMode
                        )
                    }
                }

                GroupedSettingsSection(title: "Cancel") {
                    SettingsRowView(icon: "escape", title: "Cancel Recording") {
                        KeyboardShortcutBadge(key: "Esc")
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Hotkey")
        .onAppear { appeared = true }
        .onDisappear { stopRecording() }
    }

    // MARK: - Key Recording

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            // Don't allow Escape as hotkey — it's used for cancel
            guard keyCode != 53 else {
                stopRecording()
                return nil
            }
            settings.hotkeyCode = keyCode
            coordinator.updateHotkey()
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }

    // MARK: - Key Name Display

    private func keyName(for keyCode: UInt16) -> String {
        let specialKeys: [UInt16: String] = [
            48: "Tab", 49: "Space", 36: "Return", 51: "Delete",
            53: "Esc", 76: "Enter", 123: "\u{2190}", 124: "\u{2192}",
            125: "\u{2193}", 126: "\u{2191}", 115: "Home", 119: "End",
            116: "Page Up", 121: "Page Down", 117: "\u{2326}",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
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
