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
                        withAnimation(Animations.glassMorph) {
                            calendarExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .rotationEffect(calendarExpanded ? .degrees(90) : .zero)
                                .animation(Animations.glassMorph, value: calendarExpanded)
                            Image(systemName: "calendar")
                                .font(Typography.headline)
                            Text("Calendar")
                                .font(Typography.headline)
                            Spacer()
                        }
                        .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .buttonStyle(.plain)

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
                    ForEach(viewModel.groupedTranscriptions) { group in
                        let isExpanded = !viewModel.collapsedGroups.contains(group.id)

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            // Collapsible day header
                            Button {
                                withAnimation(Animations.glassMorph) {
                                    viewModel.toggleGroup(group.id)
                                }
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                                        .animation(Animations.glassMorph, value: isExpanded)
                                    Text(group.title)
                                        .font(Typography.headline)
                                    Text("\(group.records.count)")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textTertiary)
                                    Spacer()
                                }
                                .foregroundStyle(ColorTokens.textPrimary)
                            }
                            .buttonStyle(.plain)

                            if isExpanded {
                                ForEach(group.records, id: \.timestamp) { record in
                                    TranscriptRowView(
                                        appName: record.appName,
                                        appBundleID: record.appBundleID,
                                        timestamp: record.timestamp,
                                        preview: record.processedText
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
