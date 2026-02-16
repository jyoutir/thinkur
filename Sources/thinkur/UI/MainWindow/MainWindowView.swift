import SwiftUI

struct MainWindowView: View {
    @State private var selectedPage: NavigationPage = .home

    var body: some View {
        GlassEffectContainer {
            NavigationSplitView {
                SidebarView(selectedPage: $selectedPage)
            } detail: {
                ContentRouter(page: selectedPage)
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }
}
