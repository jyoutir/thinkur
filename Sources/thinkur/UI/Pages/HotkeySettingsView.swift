import SwiftUI
import Cocoa

struct HotkeySettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator
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
        HotkeyDisplayHelper.displayName(
            keyCode: settings.hotkeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        )
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
                    // Capture Fn/Globe key (keyCode 63) on either press or release
                    if event.keyCode == 63 {
                        self.settings.hotkeyCode = 63
                        self.settings.hotkeyModifiers = 0
                        self.coordinator.updateHotkey()
                        self.stopRecording()
                        return nil
                    }
                    // Track held modifiers for real-time display
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
                self.settings.hotkeyCode = keyCode
                self.settings.hotkeyModifiers = UInt(modifiers.rawValue)
                self.coordinator.updateHotkey()
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

}
