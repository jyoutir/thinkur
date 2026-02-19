import SwiftUI

struct SmartLightRowView: View {
    let light: SmartLight
    var onToggle: ((Bool) -> Void)?
    var onBrightnessChange: ((Int) -> Void)?

    @State private var sliderValue: Double = 50
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Icon, name, backend badge, toggle
            HStack(spacing: Spacing.sm) {
                Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 14))
                    .foregroundStyle(light.isOn ? .yellow : ColorTokens.textTertiary)
                    .frame(width: 20)

                Text(light.name)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Text(backendLabel(light.backend))
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)

                Toggle("", isOn: Binding(
                    get: { light.isOn },
                    set: { onToggle?($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }

            // Row 2: Brightness slider (only when light is on)
            if light.isOn {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sun.min")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Slider(value: $sliderValue, in: 1...100, step: 1) { editing in
                        isDragging = editing
                    }
                    .controlSize(.small)

                    Image(systemName: "sun.max")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Text("\(Int(sliderValue))%")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                        .monospacedDigit()
                }
                .padding(.leading, 28) // align with name (icon width 20 + spacing)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .opacity(light.isReachable ? 1 : 0.4)
        .disabled(!light.isReachable)
        .onAppear { sliderValue = Double(light.brightness) }
        .onChange(of: light.brightness) { _, newValue in
            if !isDragging { sliderValue = Double(newValue) }
        }
        .onChange(of: sliderValue) { _, newValue in
            if isDragging { onBrightnessChange?(Int(newValue)) }
        }
    }

    private func backendLabel(_ type: SmartHomeBackendType) -> String {
        switch type {
        case .hue: return "Hue"
        case .homekit: return "HomeKit"
        case .hueBluetooth: return "Hue BLE"
        }
    }
}
