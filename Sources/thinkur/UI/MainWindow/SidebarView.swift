import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: NavigationPage
    @Environment(ShortcutsViewModel.self) private var shortcutsVM
    @Environment(SettingsManager.self) private var settings
    @Environment(SharedAppState.self) private var sharedState
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(UpdaterService.self) private var updaterService
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
                    color: sharedState.appState == .listening ? settings.accentColor : Color(red: 0.83, green: 0.55, blue: 0.38),
                    pixelSize: 4,
                    spacing: 2,
                    glowIntensity: 0.8
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(phrases.isEmpty ? "Hello..." : phrases[currentPhraseIndex])
                        .font(Typography.headline)
                        .foregroundStyle(settings.accentUITint)
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
            .task {
                guard phrases.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    guard !Task.isCancelled else { break }
                    withAnimation {
                        currentPhraseIndex = (currentPhraseIndex + 1) % phrases.count
                    }
                }
            }

            // Main pages
            VStack(spacing: 2) {
                ForEach(NavigationPage.mainPages) { page in
                    mainPageRow(for: page)
                }
            }
            .padding(.horizontal, Spacing.xs)

            Spacer(minLength: 0)

            if updaterService.updateAvailable {
                Button {
                    updaterService.checkForUpdates()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        if let version = updaterService.availableVersion {
                            Text("Update to v\(version)")
                                .font(Typography.caption)
                                .fontWeight(.medium)
                        } else {
                            Text("Update Available")
                                .font(Typography.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .background(settings.accentUITint, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
                .transition(.blurReplace)
            }

            Divider()

            // Settings pinned at bottom
            settingsSection

            Divider()

            // Theme toggle + plan badge
            HStack(spacing: 0) {
                Button {
                    settings.themeMode = settings.themeMode.next
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: settings.themeMode.iconName)
                            .font(.system(size: 13))
                        Text(settings.themeMode.title)
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if let plan = licenseManager.planName {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: plan == "Lifetime" ? "infinity" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 8))
                        Text(plan)
                            .font(Typography.caption)
                    }
                    .foregroundStyle(Color(light: .white, dark: .black))
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(ColorTokens.textPrimary, in: Capsule())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
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

                // Accent color dots
                HStack(spacing: 4) {
                    ForEach(AccentColor.allCases) { accent in
                        let isSelected = settings.accentColorName == accent.rawValue
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                settings.accentColorName = accent.rawValue
                            }
                        } label: {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 15, height: 15)
                                .overlay(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 6, height: 6)
                                        .opacity(isSelected ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(accent.displayName)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                .transition(.blurReplace)
            }
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func mainPageRow(for page: NavigationPage) -> some View {
        let isSelected = selectedPage == page
        Button {
            selectedPage = page
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: page.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? settings.accentUITint : ColorTokens.textSecondary)
                    .frame(width: 18)

                Text(page.title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if page == .shortcuts && shortcutsVM.shortcutCount > 0 {
                    Text("\(shortcutsVM.shortcutCount)")
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.border, in: Capsule())
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, Spacing.sm)
            .background(
                isSelected ? settings.accentUITint.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingsRow(for page: NavigationPage) -> some View {
        let isSelected = selectedPage == page
        Button {
            selectedPage = page
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: page.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? settings.accentUITint : ColorTokens.textSecondary)
                    .frame(width: 18)

                Text(page.title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, Spacing.sm)
            .background(
                isSelected ? settings.accentUITint.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xs)
    }
}
