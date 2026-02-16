import SwiftUI

struct HotkeySettingsView: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Configure the keyboard shortcut for voice typing.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Activation") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "keyboard", iconColor: ColorTokens.accentBlue, title: "Record Shortcut") {
                            KeyboardShortcutBadge(key: hotkeyDisplayName)
                        }

                        Divider()

                        ToggleRow(
                            icon: "hand.tap",
                            iconColor: ColorTokens.accentOrange,
                            title: "Hold Mode",
                            subtitle: "Hold key to record, release to stop",
                            isOn: $s.hotkeyHoldMode
                        )
                    }
                }

                GroupedSettingsSection(title: "Cancel") {
                    SettingsRowView(icon: "escape", iconColor: ColorTokens.textSecondary, title: "Cancel Recording") {
                        KeyboardShortcutBadge(key: "Esc")
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Hotkey")
    }

    private var hotkeyDisplayName: String {
        switch settings.hotkeyCode {
        case 48: return "Tab"
        default: return "Key \(settings.hotkeyCode)"
        }
    }
}
