import AVFoundation

enum SoundStyle: String, CaseIterable, Identifiable {
    case chime
    case click
    case minimal
    case bubble

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chime: "Chime"
        case .click: "Click"
        case .minimal: "Minimal"
        case .bubble: "Bubble"
        }
    }

    var icon: String {
        switch self {
        case .chime: "bell"
        case .click: "hand.tap"
        case .minimal: "minus"
        case .bubble: "drop"
        }
    }
}

@MainActor
final class ToneGenerator {
    static let shared = ToneGenerator()

    private let sampleRate: Double = 44100

    func playStartTone(style: SoundStyle) {
        let samples = generateStartSamples(style: style)
        play(samples)
    }

    func playStopTone(style: SoundStyle) {
        let samples = generateStopSamples(style: style)
        play(samples)
    }

    func preview(style: SoundStyle) {
        let start = generateStartSamples(style: style)
        let gapSamples = Int(sampleRate * 0.3)
        let stop = generateStopSamples(style: style)
        let combined = start + [Float](repeating: 0, count: gapSamples) + stop
        play(combined)
    }

    // MARK: - Start Tone Generation

    private func generateStartSamples(style: SoundStyle) -> [Float] {
        switch style {
        case .chime:
            return twoNoteTone(freq1: 523.25, dur1: 0.05, freq2: 659.25, dur2: 0.06, amplitude: 0.4)
        case .click:
            return singleTone(frequency: 1200, duration: 0.02, amplitude: 0.35, decay: 0.015)
        case .minimal:
            return singleTone(frequency: 880, duration: 0.03, amplitude: 0.2, decay: 0.02)
        case .bubble:
            return frequencySweep(startFreq: 400, endFreq: 800, duration: 0.05, amplitude: 0.35)
        }
    }

    // MARK: - Stop Tone Generation

    private func generateStopSamples(style: SoundStyle) -> [Float] {
        switch style {
        case .chime:
            return singleTone(frequency: 440, duration: 0.08, amplitude: 0.35, decay: 0.05)
        case .click:
            return singleTone(frequency: 800, duration: 0.02, amplitude: 0.25, decay: 0.015)
        case .minimal:
            return singleTone(frequency: 660, duration: 0.03, amplitude: 0.18, decay: 0.02)
        case .bubble:
            return frequencySweep(startFreq: 800, endFreq: 400, duration: 0.06, amplitude: 0.3)
        }
    }

    // MARK: - Waveform Generators

    private func singleTone(frequency: Double, duration: Double, amplitude: Float, decay: Double) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        let attackSamples = Int(sampleRate * 0.003)
        let decaySamples = Int(sampleRate * decay)
        var samples = [Float](repeating: 0, count: totalSamples)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let wave = Float(sin(2.0 * .pi * frequency * t))

            // Envelope: attack ramp, sustain, decay ramp
            let envelope: Float
            if i < attackSamples {
                envelope = Float(i) / Float(attackSamples)
            } else if i >= totalSamples - decaySamples {
                let remaining = Float(totalSamples - i) / Float(decaySamples)
                envelope = remaining
            } else {
                envelope = 1.0
            }

            samples[i] = wave * amplitude * envelope
        }
        return samples
    }

    private func twoNoteTone(freq1: Double, dur1: Double, freq2: Double, dur2: Double, amplitude: Float) -> [Float] {
        let note1 = singleTone(frequency: freq1, duration: dur1, amplitude: amplitude, decay: dur1 * 0.4)
        let note2 = singleTone(frequency: freq2, duration: dur2, amplitude: amplitude, decay: dur2 * 0.5)
        return note1 + note2
    }

    private func frequencySweep(startFreq: Double, endFreq: Double, duration: Double, amplitude: Float) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        let attackSamples = Int(sampleRate * 0.003)
        let decaySamples = Int(sampleRate * 0.015)
        var samples = [Float](repeating: 0, count: totalSamples)
        var phase: Double = 0

        for i in 0..<totalSamples {
            let progress = Double(i) / Double(totalSamples)
            let freq = startFreq + (endFreq - startFreq) * progress
            phase += 2.0 * .pi * freq / sampleRate
            let wave = Float(sin(phase))

            let envelope: Float
            if i < attackSamples {
                envelope = Float(i) / Float(attackSamples)
            } else if i >= totalSamples - decaySamples {
                envelope = Float(totalSamples - i) / Float(decaySamples)
            } else {
                envelope = 1.0
            }

            samples[i] = wave * amplitude * envelope
        }
        return samples
    }

    // MARK: - Playback

    /// Reusable audio engine — avoids ~5ms allocation + setup cost per tone.
    /// Kept alive between tones; source node is swapped for each new sound.
    private var engine: AVAudioEngine?
    private var currentSourceNode: AVAudioSourceNode?
    private var stopWorkItem: DispatchWorkItem?

    private func play(_ samples: [Float]) {
        // Cancel any pending stop from a previous tone
        stopWorkItem?.cancel()

        // Tear down previous source node
        if let node = currentSourceNode {
            engine?.detach(node)
            currentSourceNode = nil
        }

        let eng: AVAudioEngine
        if let existing = engine {
            existing.stop()
            eng = existing
        } else {
            eng = AVAudioEngine()
            engine = eng
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        var index = 0
        let totalSamples = samples.count

        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                if index < totalSamples {
                    ptr[frame] = samples[index]
                    index += 1
                } else {
                    ptr[frame] = 0
                }
            }
            return noErr
        }

        eng.attach(sourceNode)
        eng.connect(sourceNode, to: eng.mainMixerNode, format: format)
        currentSourceNode = sourceNode

        do {
            try eng.start()
        } catch {
            return
        }

        // Schedule engine stop after samples complete plus small buffer
        let durationSeconds = Double(totalSamples) / sampleRate + 0.05
        let workItem = DispatchWorkItem { [weak self] in
            self?.engine?.stop()
        }
        stopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds, execute: workItem)
    }
}
