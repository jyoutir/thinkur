import SwiftUI

/// Pixelated audio bar visualization with discrete pixel heights and green baseline.
/// Designed to match the notch pixel aesthetic.
struct PixelatedAudioBar: View {
    let amplitudes: [Double]
    var barCount: Int = 21
    var pixelSize: CGFloat = 3.0  // 3pt pixels
    var spacing: CGFloat = 1.0
    var baselineColor: Color = AccentColor.defaultGreen.color

    // Snap amplitude to discrete pixel heights (5 levels: 2, 3, 4, 5, 6 pixels)
    private func pixelHeight(for amplitude: Double) -> CGFloat {
        let clamped = min(max(amplitude, 0.0), 1.0)
        if clamped < 0.20 {
            return pixelSize * 2  // 2 pixels (6pt)
        } else if clamped < 0.40 {
            return pixelSize * 3  // 3 pixels (9pt)
        } else if clamped < 0.60 {
            return pixelSize * 4  // 4 pixels (12pt)
        } else if clamped < 0.80 {
            return pixelSize * 5  // 5 pixels (15pt)
        } else {
            return pixelSize * 6  // 6 pixels (18pt)
        }
    }

    var body: some View {
        let sampled = sampleAmplitudes(amplitudes, targetCount: barCount)
        let barsWidth = CGFloat(barCount) * pixelSize + CGFloat(barCount - 1) * spacing

        ZStack {
            // Solid black background
            Rectangle()
                .fill(Color.black)

            VStack(spacing: 2) {
                // Pixelated bars
                HStack(spacing: spacing) {
                    ForEach(Array(sampled.enumerated()), id: \.offset) { _, amplitude in
                        PixelBar(
                            height: pixelHeight(for: amplitude),
                            size: pixelSize,
                            color: .white  // White bars on black background
                        )
                    }
                }

                // Green baseline - centered, same width as bars
                Rectangle()
                    .fill(baselineColor)
                    .frame(width: barsWidth, height: 1)
            }
            .padding(.horizontal, 12)  // Centers content with padding
        }
        .frame(width: 100, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sampleAmplitudes(_ buffer: [Double], targetCount: Int) -> [Double] {
        if buffer.isEmpty { return Array(repeating: 0.0, count: targetCount) }
        if buffer.count == targetCount { return buffer }
        if buffer.count < targetCount {
            return Array(repeating: 0.0, count: targetCount - buffer.count) + buffer
        }
        return (0..<targetCount).map { i in
            let start = i * buffer.count / targetCount
            let end = (i + 1) * buffer.count / targetCount
            let slice = buffer[start..<end]
            return slice.reduce(0.0, +) / Double(slice.count)
        }
    }
}

private struct PixelBar: View {
    let height: CGFloat
    let size: CGFloat
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: height)
            .animation(Animations.waveformTick, value: height)
    }
}
