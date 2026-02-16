import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @State private var appeared = false
    @State private var calendarExpanded = false

    var body: some View {
        @Bindable var vm = viewModel

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

                // Collapsible calendar
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Button {
                        withAnimation(Animations.springBounce) {
                            calendarExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(Typography.headline)
                            Text("Calendar")
                                .font(Typography.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(Typography.caption)
                                .rotationEffect(.degrees(calendarExpanded ? 90 : 0))
                                .animation(Animations.springBounce, value: calendarExpanded)
                        }
                        .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .buttonStyle(.plain)

                    if calendarExpanded {
                        MiniCalendarView(
                            activeDateStrings: viewModel.activeDateStrings,
                            selectedDay: Binding(
                                get: { viewModel.selectedDay },
                                set: { viewModel.selectDay($0) }
                            )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Filter indicator
                if let day = viewModel.selectedDay {
                    HStack(spacing: Spacing.sm) {
                        Text("Showing: \(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Spacer()
                        Button("Clear") {
                            viewModel.selectDay(nil)
                        }
                        .font(Typography.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .glassCard()
                }

                // Grouped transcriptions
                if viewModel.groupedTranscriptions.isEmpty {
                    GlassEmptyState(
                        icon: "mic",
                        title: "No transcriptions yet",
                        subtitle: "Press Tab to start dictating"
                    )
                } else {
                    ForEach(Array(viewModel.groupedTranscriptions.enumerated()), id: \.element.id) { groupIndex, group in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(group.title)
                                .font(Typography.title3)
                                .foregroundStyle(ColorTokens.textPrimary)

                            ForEach(Array(group.records.enumerated()), id: \.element.timestamp) { recordIndex, record in
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
                                .animation(
                                    Animations.glassMaterialize.delay(min(Double(groupIndex * 3 + recordIndex) * 0.05, 0.5)),
                                    value: appeared
                                )
                            }
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
        .task { await viewModel.loadData() }
        .onAppear { appeared = true }
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
