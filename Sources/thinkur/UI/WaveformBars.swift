import SwiftUI

/// Pixelated waveform driven by live audio amplitude, ported from Flutter's
/// LiveAudioWaveform pattern: each bar reads one sample from the ring buffer,
/// newest on the right, naturally scrolling left as new audio arrives.
///
/// Brightness per pixel uses a gaussian bell curve centered on the middle row.
/// The bell's width (sigma) scales with amplitude — quiet bars are narrow
/// (center pixel only), loud bars are wide (all 5 rows). This avoids hard
/// on/off thresholds that cause a "green rectangle" during continuous speech.
struct WaveformBars: View {
    var amplitudes: [Double]
    var startIndex: Int
    var barCount: Int = 13
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
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { col in
                let amp = sampleAmplitude(for: col)
                let curveIndex = min(Int(amp * 100), 100)
                let curved = Self.amplitudeCurveCache[curveIndex]
                // Gaussian width scales with amplitude:
                // quiet → narrow bell (center only), loud → wide bell (all rows)
                let sigma = max(0.3, curved * 2.0)

                VStack(spacing: spacing) {
                    ForEach(0..<pixelRows, id: \.self) { row in
                        let centerRow = pixelRows / 2
                        let distance = abs(row - centerRow)
                        let falloff = exp(-Double(distance * distance) / (2.0 * sigma * sigma))
                        // Center row always has a dim baseline; others fade to near-invisible
                        let brightness = max(
                            distance == 0 ? 0.10 : 0.04,
                            curved * falloff
                        )

                        let dot = RoundedRectangle(cornerRadius: pixelSize * 0.15)
                            .fill(color)
                            .frame(width: pixelSize, height: pixelSize)
                            .opacity(brightness)
                            .shadow(color: color.opacity(0.4 * glowIntensity * brightness),
                                    radius: 2 * glowIntensity)

                        // Skip expensive outer shadow for dim pixels (imperceptible below 0.2)
                        if brightness > 0.2 {
                            dot.shadow(color: color.opacity(0.15 * glowIntensity * brightness),
                                       radius: 6 * glowIntensity)
                        } else {
                            dot
                        }
                    }
                }
            }
        }
        // Flatten the pixel grid into a single Metal layer — avoids per-pixel compositor passes
        .drawingGroup()
    }

    /// Read the barCount most recent consecutive samples from the ring buffer.
    /// Bar 0 (leftmost) = oldest of the N, bar N-1 (rightmost) = newest.
    /// As new samples arrive, the entire waveform scrolls left naturally.
    private func sampleAmplitude(for barIndex: Int) -> Double {
        guard !amplitudes.isEmpty else { return 0 }
        let newestIndex = (startIndex - 1 + amplitudes.count) % amplitudes.count
        let offset = barCount - 1 - barIndex
        return amplitudes[(newestIndex - offset + amplitudes.count) % amplitudes.count]
    }
}
