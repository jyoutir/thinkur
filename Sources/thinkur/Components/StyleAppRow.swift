import SwiftUI

struct StyleAppRow: View {
    let entry: StyleAppEntry
    let onStyleChange: (String) -> Void
    var onDelete: (() -> Void)?

    private let styles = ["Standard", "Casual", "Formal", "Code"]

    var body: some View {
        HStack(spacing: Spacing.sm) {
            AppIconView(bundleID: entry.id, appName: entry.appName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.appName)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(entry.description)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove app")
            }

            Picker("", selection: Binding(
                get: { entry.style },
                set: { onStyleChange($0) }
            )) {
                ForEach(styles, id: \.self) { style in
                    Text(style).tag(style)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}
