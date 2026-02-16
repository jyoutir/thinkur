import SwiftUI
import AppKit

struct CopyButton: View {
    let text: String

    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(Typography.caption)
                .foregroundStyle(copied ? .green : ColorTokens.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .animation(Animations.springBounce, value: copied)
        }
        .buttonStyle(.plain)
    }
}
