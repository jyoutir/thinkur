import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: NavigationPage
    @Environment(ShortcutsViewModel.self) private var shortcutsVM
    @Environment(SettingsManager.self) private var settings
    @Environment(SharedAppState.self) private var sharedState
    @State private var settingsExpanded = false

    // Rolling greeting state
    @State private var phrases = GreetingProvider.phrases()
    @State private var currentPhraseIndex = 0
    private let firstName = GreetingProvider.firstName

    var body: some View {
        VStack(spacing: 0) {
            // Rolling greeting
            HStack(spacing: Spacing.sm) {
                ClaudePixelSpinner(
                    state: SpinnerState(from: sharedState.appState),
                    pixelSize: 4,
                    spacing: 2,
                    glowIntensity: 0.8
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(phrases.isEmpty ? "Hello..." : phrases[currentPhraseIndex])
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.6), value: currentPhraseIndex)

                    Text(firstName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.md)
            .onAppear { startPhraseRotation() }

            // Main pages
            List(selection: $selectedPage) {
                ForEach(NavigationPage.mainPages) { page in
                    sidebarLabel(for: page)
                        .tag(page)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
            }
            .listStyle(.sidebar)

            Spacer(minLength: 0)

            Divider()

            // Settings pinned at bottom
            settingsSection

            Divider()

            // Theme toggle — whole row clickable, light/dark only
            Button {
                settings.themeMode = settings.themeMode.next
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: settings.themeMode.iconName)
                        .font(.system(size: 13))
                    Text(settings.themeMode.title)
                        .font(Typography.caption)
                    Spacer()
                }
                .foregroundStyle(ColorTokens.textSecondary)
                .contentShape(Rectangle())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .onChange(of: selectedPage) { _, newPage in
            if newPage.section == .settings && !settingsExpanded {
                withAnimation(Animations.glassMorph) {
                    settingsExpanded = true
                }
            }
        }
    }

    // MARK: - Rolling Greeting

    private func startPhraseRotation() {
        guard phrases.count > 1 else { return }
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    currentPhraseIndex = (currentPhraseIndex + 1) % phrases.count
                }
            }
        }
    }

    // MARK: - Settings Section

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Animations.glassMorph) {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .rotationEffect(settingsExpanded ? .degrees(90) : .zero)
                        .animation(Animations.glassMorph, value: settingsExpanded)
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                    Text("Settings")
                        .font(Typography.body)
                    Spacer()
                }
                .foregroundStyle(ColorTokens.textPrimary)
                .contentShape(Rectangle())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)

            if settingsExpanded {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(NavigationPage.settingsPages) { page in
                            settingsRow(for: page)
                        }
                    }
                    .padding(.bottom, Spacing.xxs)
                }
                .frame(maxHeight: 220)
                .transition(.blurReplace)
            }
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func sidebarLabel(for page: NavigationPage) -> some View {
        Label {
            HStack {
                Text(page.title)
                if page == .shortcuts && shortcutsVM.shortcutCount > 0 {
                    Spacer()
                    Text("\(shortcutsVM.shortcutCount)")
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.border, in: Capsule())
                }
            }
        } icon: {
            Image(systemName: page.icon)
        }
    }

    @ViewBuilder
    private func settingsRow(for page: NavigationPage) -> some View {
        let isSelected = selectedPage == page
        Button {
            selectedPage = page
        } label: {
            Label(page.title, systemImage: page.icon)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, Spacing.sm)
                .background(
                    isSelected ? Color.primary.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xs)
    }
}
