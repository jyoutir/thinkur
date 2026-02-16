import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @State private var greeting = GreetingProvider.greeting()
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Personalized greeting
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(greeting)
                        .font(Typography.title)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(GreetingProvider.formattedDate)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: appeared)

                // Press Tab prompt
                HStack(spacing: Spacing.sm) {
                    Text("Press")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                    KeyboardShortcutBadge(key: "Tab")
                    Text("to start voice typing")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .glassCard()

                // Recent transcriptions
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Recent Activity")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.recentTranscriptions.isEmpty {
                        emptyState(
                            icon: "mic",
                            title: "No transcriptions yet",
                            subtitle: "Press Tab to start dictating"
                        )
                    } else {
                        ForEach(Array(viewModel.recentTranscriptions.enumerated()), id: \.element.timestamp) { index, record in
                            TranscriptRowView(
                                appName: record.appName,
                                appBundleID: record.appBundleID,
                                timestamp: record.timestamp,
                                preview: record.processedText
                            )
                            .padding(Spacing.sm)
                            .glassCard()
                            .hoverBrightness()
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: appeared)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Home")
        .task {
            await viewModel.loadData()
            appeared = true
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))

            Text(title)
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Hover Brightness Modifier

private struct HoverBrightnessModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovered ? 0.03 : 0)
            .animation(Animations.hoverFade, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverBrightness() -> some View {
        modifier(HoverBrightnessModifier())
    }
}
