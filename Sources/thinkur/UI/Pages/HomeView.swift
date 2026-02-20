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

                // Summary stats + Press Tab prompt
                HStack(spacing: Spacing.sm) {
                    StatPill(value: Formatters.formatTimeSaved(viewModel.totalTimeSaved), label: "saved")
                    StatPill(value: Formatters.compactNumber(viewModel.totalWords), label: "words")

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        Text("Press")
                            .font(Typography.callout)
                            .foregroundStyle(ColorTokens.textTertiary)
                        KeyboardShortcutBadge(key: "Tab")
                        Text("to start")
                            .font(Typography.callout)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                // Collapsible calendar
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        // Arrow button - triggers expand/collapse
                        Button {
                            withAnimation(Animations.glassMorph) {
                                calendarExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .rotationEffect(calendarExpanded ? .degrees(90) : .zero)
                                .animation(Animations.glassMorph, value: calendarExpanded)
                        }
                        .buttonStyle(.plain)

                        // Header - non-interactive
                        Image(systemName: "calendar")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("Calendar")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                    }

                    if calendarExpanded {
                        MiniCalendarView(
                            activeDateStrings: viewModel.activeDateStrings,
                            rangeStart: Binding(
                                get: { viewModel.rangeStart },
                                set: { _ in }
                            ),
                            rangeEnd: Binding(
                                get: { viewModel.rangeEnd },
                                set: { _ in }
                            ),
                            onSelectDate: { viewModel.selectDate($0) }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Filter indicator
                if let description = viewModel.filterDescription {
                    HStack(spacing: Spacing.sm) {
                        Text("Showing: \(description)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Spacer()
                        Button("Clear") {
                            viewModel.clearFilter()
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
                    ForEach(viewModel.groupedTranscriptions, id: \.id) { group in
                        let isExpanded = !viewModel.collapsedGroups.contains(group.id)

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            // Collapsible day header
                            HStack(spacing: Spacing.xs) {
                                // Arrow button - triggers expand/collapse
                                Button {
                                    withAnimation(Animations.glassMorph) {
                                        viewModel.toggleGroup(group.id)
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                                        .animation(Animations.glassMorph, value: isExpanded)
                                }
                                .buttonStyle(.plain)

                                // Header text - non-interactive
                                Text(group.title)
                                    .font(Typography.headline)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Text("\(group.records.count)")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Spacer()
                            }

                            if isExpanded {
                                ForEach(group.records, id: \.timestamp) { record in
                                    TranscriptRowView(
                                        appName: record.appName,
                                        appBundleID: record.appBundleID,
                                        timestamp: record.timestamp,
                                        preview: record.processedText,
                                        rawText: record.rawText,
                                        correctionCount: record.correctionCount
                                    )
                                    .padding(Spacing.sm)
                                    .glassCard()
                                    .hoverBrightness()
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
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
        .onChange(of: viewModel.transcriptionVersion) {
            Task { await viewModel.loadData() }
        }
        .onAppear { appeared = true }
    }

}

// MARK: - Stat Pill

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(value)
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassCard()
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
