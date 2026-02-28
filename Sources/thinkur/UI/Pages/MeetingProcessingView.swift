import SwiftUI

struct MeetingProcessingView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            Text("Processing meeting transcript...")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("This may take a moment for longer meetings.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
    }
}
