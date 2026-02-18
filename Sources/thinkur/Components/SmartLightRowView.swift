import SwiftUI

struct SmartLightRowView: View {
    let light: SmartLight

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: 14))
                .foregroundStyle(light.isOn ? .yellow : ColorTokens.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(light.name)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.xs) {
                    Text(light.isOn ? "On" : "Off")
                        .foregroundStyle(light.isOn ? ColorTokens.textPrimary : ColorTokens.textTertiary)

                    if light.isOn && light.brightness > 0 {
                        Text("\(light.brightness)%")
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    if !light.isReachable {
                        Text("Unreachable")
                            .foregroundStyle(ColorTokens.danger)
                    }
                }
                .font(Typography.caption)
            }

            Spacer()

            Text(backendLabel(light.backend))
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
    }

    private func backendLabel(_ type: SmartHomeBackendType) -> String {
        switch type {
        case .hue: return "Hue"
        case .homekit: return "HomeKit"
        case .hueBluetooth: return "Hue BLE"
        }
    }
}
