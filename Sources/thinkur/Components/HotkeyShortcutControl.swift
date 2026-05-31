import SwiftUI

struct HotkeyShortcutControl: View {
    let selection: HotkeyShortcutOption
    let isRecording: Bool
    let shortcutLabel: String
    let recordingLabel: String
    let accentTint: Color
    let onSelect: (HotkeyShortcutOption) -> Void
    let onToggleRecording: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(HotkeyShortcutOption.allCases) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Label(option.displayName, systemImage: option.systemImageName)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selection.systemImageName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == .custom ? ColorTokens.textSecondary : accentTint)
                        .frame(width: 16)

                    Text(selection.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                        .fixedSize()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.leading, Spacing.xs)
                .padding(.trailing, Spacing.xs)
                .frame(height: 28)
                .contentShape(Rectangle())
            }

            if selection == .custom {
                Rectangle()
                    .fill(ColorTokens.border)
                    .frame(width: 1, height: 16)

                Button(action: onToggleRecording) {
                    HStack(spacing: 5) {
                        Image(systemName: isRecording ? "record.circle" : "keyboard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isRecording ? accentTint : ColorTokens.textTertiary)
                            .frame(width: 14)

                        Text(isRecording ? recordingLabel : shortcutLabel)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, Spacing.xs)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(ColorTokens.border.opacity(0.22), in: RoundedRectangle(cornerRadius: CornerRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.button)
                .strokeBorder(ColorTokens.border.opacity(0.75), lineWidth: 1)
        )
        .buttonStyle(.plain)
    }
}

private extension HotkeyShortcutOption {
    var systemImageName: String {
        switch self {
        case .rightOption:
            return "option"
        case .rightCommand:
            return "command"
        case .custom:
            return "keyboard"
        }
    }
}
