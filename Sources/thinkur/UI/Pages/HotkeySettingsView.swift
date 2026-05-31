import SwiftUI
import Cocoa

struct HotkeySettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator
    @State private var appeared = false
    @StateObject private var recorder = HotkeyRecordingSession()

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
                            HotkeyShortcutControl(
                                selection: settings.hotkeyShortcutOption,
                                isRecording: recorder.isRecording,
                                shortcutLabel: currentHotkeyLabel,
                                recordingLabel: recorder.recordingLabel,
                                accentTint: settings.accentUITint,
                                onSelect: selectHotkeyShortcutOption,
                                onToggleRecording: toggleRecording
                            )
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
        .onDisappear { recorder.stopRecording() }
    }

    // MARK: - Display

    private var currentHotkeyLabel: String {
        HotkeyDisplayHelper.displayName(
            keyCode: settings.effectiveHotkeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.effectiveHotkeyModifiers))
        )
    }

    private func selectHotkeyShortcutOption(_ option: HotkeyShortcutOption) {
        recorder.selectShortcutOption(
            option,
            applySelection: coordinator.selectHotkeyShortcutOption,
            onCustomCommit: coordinator.applyCustomHotkey
        )
    }

    private func toggleRecording() {
        recorder.toggleRecording(onCommit: coordinator.applyCustomHotkey)
    }

}
