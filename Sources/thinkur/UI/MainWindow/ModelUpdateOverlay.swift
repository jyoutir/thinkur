import SwiftUI

struct ModelUpdateOverlay: View {
    @Environment(SharedAppState.self) private var sharedState
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThickMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ClaudePixelSpinner(state: .connecting)

                VStack(spacing: Spacing.xs) {
                    Text("Getting things set up")
                        .font(Typography.onboardingTitle)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(sharedState.modelLoadingMessage.isEmpty ? "Almost ready\u{2026}" : sharedState.modelLoadingMessage)
                        .font(Typography.onboardingBody)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: sharedState.modelLoadingMessage)
                }

                ProgressView(value: sharedState.modelDownloadProgress)
                    .tint(settings.accentUITint)
                    .frame(maxWidth: 280)
                    .animation(.easeInOut(duration: 0.3), value: sharedState.modelDownloadProgress)
            }
        }
    }
}
