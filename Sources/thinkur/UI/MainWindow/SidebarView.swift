import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: NavigationPage
    @Environment(ShortcutsViewModel.self) private var shortcutsVM

    var body: some View {
        List(selection: $selectedPage) {
            Section("Main") {
                ForEach(NavigationPage.mainPages) { page in
                    sidebarLabel(for: page)
                        .tag(page)
                }
            }

            Section("Settings") {
                ForEach(NavigationPage.settingsPages) { page in
                    sidebarLabel(for: page)
                        .tag(page)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
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
}
