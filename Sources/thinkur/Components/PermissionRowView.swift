import SwiftUI

struct PermissionRowView: View {
    @Environment(SettingsManager.self) private var settings
    let icon: String
    let name: String
    let description: String
    let isGranted: Bool
    var helpText: String = ""
    let action: () -> Void

    @State private var showHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(settings.accentUITint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(description)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                if !helpText.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHelp.toggle()
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                if isGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.success)
                } else {
                    Button("Grant") {
                        action()
                        withAnimation(.easeInOut(duration: 0.2)) { showHelp = true }
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            if showHelp {
                Text(helpText)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.leading, 28 + Spacing.sm)
                    .padding(.bottom, Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
