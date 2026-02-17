import SwiftUI
import AppKit

struct TranscriptRowView: View {
    let appName: String
    let appBundleID: String
    let timestamp: Date
    let preview: String

    @State private var copied = false
    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Normal content
            HStack(spacing: Spacing.sm) {
                AppIconView(bundleID: appBundleID, appName: appName, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(appName)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .opacity(isHovered && !copied ? 1 : 0)
                        Text(timestamp, format: .dateTime.hour().minute())
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Text(preview)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .opacity(copied ? 0 : 1)

            // Copied overlay
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                Text("Copied to clipboard")
                    .font(Typography.body)
            }
            .foregroundStyle(ColorTokens.textPrimary)
            .opacity(copied ? 1 : 0)
            .scaleEffect(copied ? 1 : 0.8)
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture { copyText() }
        .onHover { isHovered = $0 }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: copied)
        .animation(Animations.hoverFade, value: isHovered)
    }

    private func copyText() {
        guard !copied else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preview, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
