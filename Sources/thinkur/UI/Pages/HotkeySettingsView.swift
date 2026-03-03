import SwiftUI
import Cocoa
import KeyboardShortcuts
import Carbon.HIToolbox

struct HotkeySettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var currentModifiers: NSEvent.ModifierFlags = []

    private static let standardModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

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
                            VStack(alignment: .trailing, spacing: 4) {
                                Button {
                                    if isRecording {
                                        stopRecording()
                                    } else {
                                        startRecording()
                                    }
                                } label: {
                                    KeyboardShortcutBadge(
                                        key: isRecording ? recordingLabel : currentHotkeyLabel
                                    )
                                }
                                .buttonStyle(.plain)

                                if isRecording {
                                    Text("Hold modifiers, then press a key")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                            }
                        }

                        Divider()

                        ToggleRow(
                            icon: "hand.tap",
                            title: "Push to Talk",
                            subtitle: "Hold to dictate, release to finish",
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

    // MARK: - Display

    private var currentHotkeyLabel: String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) {
            return HotkeyDisplayHelper.displayName(
                keyCode: UInt16(shortcut.carbonKeyCode),
                modifiers: shortcut.toNSEventModifiers()
            )
        }
        return "Not set"
    }

    private var recordingLabel: String {
        let mods = HotkeyDisplayHelper.modifierSymbols(for: currentModifiers)
        if mods.isEmpty {
            return "Type shortcut\u{2026}"
        }
        return "\(mods)+ key\u{2026}"
    }

    // MARK: - Key Recording

    private func startRecording() {
        isRecording = true
        // Small delay before installing monitor to flush any stale key events
        // (e.g. from keyboard-activating the button itself)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard self.isRecording else { return }
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                if event.type == .flagsChanged {
                    // Track held modifiers for real-time display
                    // (Fn/Globe key 63 dropped — Carbon can't register modifier-only keys)
                    self.currentModifiers = event.modifierFlags.intersection(Self.standardModifiers)
                    return event
                }

                let keyCode = event.keyCode
                // Escape cancels recording
                guard keyCode != 53 else {
                    self.stopRecording()
                    return nil
                }

                let modifiers = event.modifierFlags.intersection(Self.standardModifiers)
                let carbonMods = convertNSEventToCarbonModifiers(modifiers)
                KeyboardShortcuts.setShortcut(
                    .init(carbonKeyCode: Int(Int32(keyCode)), carbonModifiers: carbonMods),
                    for: .toggleRecording
                )
                self.stopRecording()
                return nil
            }
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        currentModifiers = []
        isRecording = false
    }

    private func convertNSEventToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        return carbon
    }
}

// MARK: - KeyboardShortcuts.Shortcut helpers

extension KeyboardShortcuts.Shortcut {
    func toNSEventModifiers() -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        let carbon = carbonModifiers
        if carbon & cmdKey != 0 { flags.insert(.command) }
        if carbon & optionKey != 0 { flags.insert(.option) }
        if carbon & controlKey != 0 { flags.insert(.control) }
        if carbon & shiftKey != 0 { flags.insert(.shift) }
        return flags
    }
}
