import SwiftUI

struct ContentRouter: View {
    let page: NavigationPage

    var body: some View {
        Group {
            switch page {
            case .home:
                HomeView()
            case .shortcuts:
                ShortcutsView()
            case .style:
                StyleView()
            case .insights:
                InsightsView()
            case .meetings:
                MeetingsView()
            case .mcp:
                MCPView()
            case .hue:
                HueView()
            case .hotkey:
                HotkeySettingsView()
            case .dictation:
                DictationSettingsView()
            case .system:
                SystemSettingsView()
            case .permissions:
                PermissionsView()
            case .billing:
                BillingView()
            case .support:
                SupportView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.blurReplace)
        .id(page)
        .animation(Animations.glassMorph, value: page)
    }
}
