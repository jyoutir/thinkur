import SwiftUI

struct PermissionRowView: View {
    let icon: String
    let name: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
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

            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.success)
            } else {
                Button("Grant", action: action)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}
