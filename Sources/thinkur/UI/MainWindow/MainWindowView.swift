import SwiftUI

struct MainWindowView: View {
    @State private var selectedPage: NavigationPage = .home
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedPage: $selectedPage)
        } detail: {
            ContentRouter(page: selectedPage)
        }
        .frame(minWidth: 920, minHeight: 620)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    settings.themeMode = settings.themeMode.next
                } label: {
                    Image(systemName: settings.themeMode.iconName)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .help("Toggle theme: \(settings.themeMode.rawValue)")
            }
        }
    }
}
