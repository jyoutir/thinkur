import SwiftUI

struct MainWindowView: View {
    @Environment(SharedAppState.self) private var sharedState
    @State private var selectedPage: NavigationPage = .home

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedPage: $selectedPage)
        } detail: {
            ContentRouter(page: selectedPage)
        }
        .frame(minWidth: 920, minHeight: 620)
        .overlay {
            if sharedState.isModelLoading {
                ModelUpdateOverlay()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
    }
}
