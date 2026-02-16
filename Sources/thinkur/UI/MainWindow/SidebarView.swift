import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: NavigationPage
    @Environment(ShortcutsViewModel.self) private var shortcutsVM
    @Environment(SettingsManager.self) private var settings
    @State private var settingsExpanded = false
    @State private var greeting = GreetingProvider.greeting()

    var body: some View {
        VStack(spacing: 0) {
            // Greeting pinned at top
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(GreetingProvider.formattedDate)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)

            // Main pages
            List(selection: $selectedPage) {
                ForEach(NavigationPage.mainPages) { page in
                    sidebarLabel(for: page)
                        .tag(page)
                }
            }
            .listStyle(.sidebar)

            Spacer(minLength: 0)

            Divider()

            // Settings pinned at bottom
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settingsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .rotationEffect(settingsExpanded ? .degrees(90) : .zero)
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                        Text("Settings")
                            .font(Typography.body)
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.plain)

                if settingsExpanded {
                    VStack(spacing: 1) {
                        ForEach(NavigationPage.settingsPages) { page in
                            settingsRow(for: page)
                        }
                    }
                    .padding(.top, Spacing.xxs)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.vertical, Spacing.xs)

            Divider()

            // Theme toggle
            Button {
                let nextMode = settings.themeMode.next
                settings.themeMode = nextMode
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: settings.themeMode.iconName)
                        .font(.system(size: 13))
                    Text(settings.themeMode.rawValue.capitalized)
                        .font(Typography.caption)
                }
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .onChange(of: selectedPage) { _, newPage in
            if newPage.section == .settings && !settingsExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    settingsExpanded = true
                }
            }
        }
    }

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
                .foregroundStyle(isSelected ? .white : ColorTokens.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, Spacing.sm)
                .background(
                    isSelected ? Color.accentColor : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.sm)
    }
}
