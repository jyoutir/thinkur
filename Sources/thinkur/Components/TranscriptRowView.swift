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
        HStack(spacing: Spacing.sm) {
            if copied {
                Image(systemName: "checkmark")
                    .font(Typography.body)
                    .foregroundStyle(.green)
                    .frame(width: 36, height: 36)
            } else {
                AppIconView(bundleID: appBundleID, appName: appName, size: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(copied ? "Copied to clipboard" : appName)
                        .font(Typography.body)
                        .foregroundStyle(copied ? .green : ColorTokens.textPrimary)
                    Spacer()
                    if !copied {
                        if isHovered {
                            Image(systemName: "doc.on.doc")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                                .transition(.opacity)
                        }
                        Text(timestamp, format: .dateTime.hour().minute())
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                if !copied {
                    Text(preview)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture { copyText() }
        .onHover { isHovered = $0 }
        .animation(Animations.hoverFade, value: copied)
        .animation(Animations.hoverFade, value: isHovered)
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preview, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }
}
