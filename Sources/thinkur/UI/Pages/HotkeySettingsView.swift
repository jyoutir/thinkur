import SwiftUI

struct HotkeySettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Configure the keyboard shortcut for voice typing.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Activation") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "keyboard", iconColor: .primary, title: "Record Shortcut") {
                            KeyboardShortcutBadge(key: hotkeyDisplayName)
                        }

                        Divider()

                        ToggleRow(
                            icon: "hand.tap",
                            iconColor: .primary,
                            title: "Hold Mode",
                            subtitle: "Hold key to record, release to stop",
                            isOn: $s.hotkeyHoldMode
                        )
                    }
                }

                GroupedSettingsSection(title: "Cancel") {
                    SettingsRowView(icon: "escape", iconColor: .primary, title: "Cancel Recording") {
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
    }

    private var hotkeyDisplayName: String {
        switch settings.hotkeyCode {
        case 48: return "Tab"
        default: return "Key \(settings.hotkeyCode)"
        }
    }
}
