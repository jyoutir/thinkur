import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Your recent voice typing activity.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

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
                        GlassEmptyState(
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
                            .offset(y: appeared ? 0 : 8)
                            .animation(Animations.glassStagger(index: index), value: appeared)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Home")
        .task {
            await viewModel.loadData()
            appeared = true
        }
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
