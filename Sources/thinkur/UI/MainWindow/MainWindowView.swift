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
    }
}
