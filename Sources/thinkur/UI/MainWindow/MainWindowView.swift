import SwiftUI

struct MainWindowView: View {
    @State private var selectedPage: NavigationPage = .home
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer {
            NavigationSplitView {
                SidebarView(selectedPage: $selectedPage)
            } detail: {
                ContentRouter(page: selectedPage)
            }
        }
        .id(colorScheme)
        .frame(minWidth: 920, minHeight: 620)
    }
}
