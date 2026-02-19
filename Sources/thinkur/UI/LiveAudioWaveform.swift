import SwiftUI

/// Horizontal animated waveform driven by amplitude history.
struct LiveAudioWaveform: View {
    let amplitudes: [Double]
    var barCount: Int = 30
    var height: Double = 48
    var showGlass: Bool = true
    var horizontalPadding: CGFloat = LiveAudioWaveform.defaultHorizontalPadding

    static let barWidth: CGFloat = 3.0
    static let barGap: CGFloat = 2.0
    static let defaultHorizontalPadding: CGFloat = 20.0

    static func calculateMaxBars(availableWidth: CGFloat, horizontalPadding: CGFloat = defaultHorizontalPadding) -> Int {
        let barsWidth = availableWidth - (horizontalPadding * 2)
        if barsWidth <= 0 { return 3 }
        return min(max(Int((barsWidth + barGap) / (barWidth + barGap)), 3), 30)
    }

    var body: some View {
        let sampled = sampleAmplitudes(amplitudes, targetCount: barCount)

        let bars = HStack(spacing: Self.barGap) {
            ForEach(Array(sampled.enumerated()), id: \.offset) { _, amplitude in
                WaveformBar(amplitude: amplitude)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)

        if showGlass {
            bars.glassCapsule()
        } else {
            bars
        }
    }

    private func sampleAmplitudes(_ buffer: [Double], targetCount: Int) -> [Double] {
        if buffer.isEmpty { return Array(repeating: 0.0, count: targetCount) }
        if buffer.count == targetCount { return buffer }
        if buffer.count < targetCount {
            return Array(repeating: 0.0, count: targetCount - buffer.count) + buffer
        }
        return (0..<targetCount).map { i in
            let idx = min(i * buffer.count / targetCount, buffer.count - 1)
            return buffer[idx]
        }
    }
}

private struct WaveformBar: View {
    let amplitude: Double

    private static let baseHeight: CGFloat = 6.0
    private static let maxBoost: CGFloat = 18.0

    var body: some View {
        let clamped = min(max(amplitude, 0.0), 1.0)
        let barHeight = Self.baseHeight + clamped * Self.maxBoost

        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.primary)
            .frame(width: LiveAudioWaveform.barWidth, height: barHeight)
            .animation(.easeOut(duration: 0.1), value: barHeight)
    }
}
