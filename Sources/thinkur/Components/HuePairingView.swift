import SwiftUI

struct HuePairingView: View {
    let pairingState: HueBridgeBackend.PairingState
    let onConnect: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            switch pairingState {
            case .idle:
                EmptyView()

            case .discovering:
                ProgressView()
                    .controlSize(.small)
                Text("Searching for Hue Bridge...")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textSecondary)

            case .waitingForButton(let bridgeIP):
                Image(systemName: "button.programmable")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Press the button on your Hue Bridge")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Bridge found at \(bridgeIP)")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)

                ProgressView()
                    .controlSize(.small)

                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textTertiary)

            case .paired:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)

                Text("Connected!")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)

                Text(message)
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.danger)

                Button("Try Again") { onConnect() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
    }
}
