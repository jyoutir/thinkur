import SwiftUI

struct ToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        SettingsRowView(icon: icon, title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(settings.accentUITint)
        }
    }
}
