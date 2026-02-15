import SwiftUI

struct ToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        SettingsRowView(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
