import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @Environment(SharedAppState.self) private var sharedState
    @State private var appeared = false
    @State private var calendarExpanded = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Upgrade banner when free tier exhausted
                if sharedState.freeTierExhausted && sharedState.isFreeTier {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You\u{2019}ve used your 5,000 free words!")
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("Upgrade to keep dictating.")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        Spacer()
                        Button("Upgrade") {
                            if let url = URL(string: Constants.customerPortalURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settings.accentUITint)
                        .controlSize(.small)
                    }
                    .padding(Spacing.md)
                    .interactiveCard()
                }

                Text("Your recent voice typing activity.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                // Summary stats + calendar toggle + Press Tab prompt
                HStack(spacing: Spacing.sm) {
                    StatPill(value: Formatters.formatTimeSaved(viewModel.totalTimeSaved), label: "saved")
                    if sharedState.isFreeTier {
                        StatPill(value: "\(Formatters.compactNumber(viewModel.totalWords)) / \(Formatters.compactNumber(Constants.freeWordLimit))", label: "words")
                    } else {
                        StatPill(value: Formatters.compactNumber(viewModel.totalWords), label: "words")
                    }

                    Button {
                        withAnimation(Animations.glassMorph) {
                            calendarExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textTertiary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .rotationEffect(calendarExpanded ? .degrees(90) : .zero)
                                .animation(Animations.glassMorph, value: calendarExpanded)

                            if let desc = viewModel.filterDescription {
                                Text(desc)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                        .interactiveCard()
                    }
                    .buttonStyle(.plain)

                    if viewModel.rangeStart != nil {
                        Button {
                            viewModel.clearFilter()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

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

                // Calendar grid (collapsible)
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
                        displayedMonth: Binding(
                            get: { viewModel.displayedMonth },
                            set: { viewModel.displayedMonth = $0 }
                        ),
                        onSelectDate: { viewModel.selectDate($0) },
                        accentColor: settings.accentUITint
                    )
                    .frame(maxWidth: 240)
                    .onChange(of: viewModel.displayedMonth) {
                        viewModel.monthChanged()
                    }
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
                                        .foregroundStyle(ColorTokens.textPrimary)
                                    Text("\(group.records.count)")
                                        .font(Typography.caption)
                                        .foregroundStyle(settings.accentUITint)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

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
                                    .interactiveCard()
                                    .hoverBrightness()
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
    @Environment(SettingsManager.self) private var settings
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(value)
                .font(Typography.headline)
                .foregroundStyle(settings.accentUITint)
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .interactiveCard()
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
