import SwiftUI

struct AccentSwitchStyle: ToggleStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? tint : Color(.separatorColor))
                    .frame(width: 32, height: 18)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                    .frame(width: 14, height: 14)
                    .padding(2)
            }
            .animation(.spring(duration: 0.2, bounce: 0.15), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
