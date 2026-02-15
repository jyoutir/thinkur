import Combine
import Foundation

/// Rolling amplitude buffer for waveform UI.
/// Ported from Flutter AudioAmplitudeController — polls audio level at 80ms intervals,
/// applies EMA smoothing, and maintains a fixed-size buffer.
@MainActor
final class AudioAmplitudeProvider: ObservableObject {
    @Published var amplitudes: [Double]

    private let bufferSize: Int
    private let smoothingFactor: Double
    private var timer: Timer?
    private var levelSource: (() -> Float)?

    init(bufferSize: Int = 30, smoothingFactor: Double = 0.7) {
        self.bufferSize = bufferSize
        self.smoothingFactor = smoothingFactor
        self.amplitudes = Array(repeating: 0.0, count: bufferSize)
    }

    func startPolling(source: @escaping () -> Float) {
        levelSource = source
        amplitudes = Array(repeating: 0.0, count: bufferSize)
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        levelSource = nil
        // Fade out
        amplitudes = Array(repeating: 0.0, count: bufferSize)
    }

    private func tick() {
        guard let source = levelSource else { return }
        let raw = Double(source())
        let previous = amplitudes.last ?? 0.0
        // EMA smoothing: smoothed = previous * 0.3 + current * 0.7
        let smoothed = previous * (1.0 - smoothingFactor) + raw * smoothingFactor
        amplitudes = Array(amplitudes.dropFirst()) + [smoothed]
    }
}
