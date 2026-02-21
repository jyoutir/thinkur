import SwiftUI

/// Pixelated vertical bars driven by audio amplitude.
/// Each bar is a column of square pixel dots (matching ClaudePixelSpinner's aesthetic)
/// that light up from center outward based on amplitude.
struct WaveformBars: View {
    var amplitudes: [Double]
    var startIndex: Int
    var barCount: Int = 7
    var pixelRows: Int = 5
    var pixelSize: CGFloat = 3
    var spacing: CGFloat = 1
    var color: Color
    var glowIntensity: Double = 1.2

    /// Precomputed amplitude curve (0.4 exponent for low-volume sensitivity)
    private static let amplitudeCurveCache: [Double] = {
        (0...100).map { pow(Double($0) / 100.0, 0.4) }
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { _ in
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { col in
                    let amp = sampleAmplitude(for: col)
                    let curveIndex = min(Int(amp * 100), 100)
                    let curved = Self.amplitudeCurveCache[curveIndex]

                    VStack(spacing: spacing) {
                        ForEach(0..<pixelRows, id: \.self) { row in
                            let centerRow = pixelRows / 2
                            let distance = abs(row - centerRow)
                            let threshold = Double(distance) * 0.25
                            let isLit = curved > threshold
                            let brightness = isLit
                                ? 0.4 + 0.6 * min(1, (curved - threshold) / (1.0 - threshold))
                                : 0.06

                            RoundedRectangle(cornerRadius: pixelSize * 0.15)
                                .fill(color)
                                .frame(width: pixelSize, height: pixelSize)
                                .opacity(brightness)
                                .shadow(color: color.opacity(0.4 * glowIntensity * brightness),
                                        radius: 2 * glowIntensity)
                                .shadow(color: color.opacity(0.15 * glowIntensity * brightness),
                                        radius: 6 * glowIntensity)
                        }
                    }
                }
            }
        }
    }

    private func sampleAmplitude(for barIndex: Int) -> Double {
        guard !amplitudes.isEmpty else { return 0 }
        let stride = amplitudes.count / barCount
        let offset = amplitudes.count - barCount * stride + barIndex * stride
        return amplitudes[(startIndex + offset) % amplitudes.count]
    }
}
