import Testing
import Foundation
@testable import thinkur

@Suite("SilenceTrimmingTests")
struct SilenceTrimmingTests {


    /// Helper to generate a sine wave segment.
    private func sineWave(durationSeconds: Double, amplitude: Float, frequency: Float = 440.0) -> [Float] {
        let sampleRate = Constants.sampleRate
        let sampleCount = Int(durationSeconds * sampleRate)
        return (0..<sampleCount).map { i in
            amplitude * cos(2.0 * Float.pi * frequency * Float(i) / Float(sampleRate))
        }
    }

    /// Asserts exact retained sample span and exact slice preservation when digital zeros are trimmed with 150ms padding.
    @Test func exactRetainedSpanWithDigitalZeroPadding() {
        let sampleRate = Int(Constants.sampleRate)
        let leadingZeroCount = 1 * sampleRate // 16,000 zeros
        let trailingZeroCount = 1 * sampleRate // 16,000 zeros
        let paddingSamples = Int(0.15 * Constants.sampleRate) // 2,400 samples

        // 50 seconds of quiet speech samples
        let speechSamples = sineWave(durationSeconds: 50.0, amplitude: 0.003, frequency: 350.0)
        let leadingZeros = [Float](repeating: 0.0, count: leadingZeroCount)
        let trailingZeros = [Float](repeating: 0.0, count: trailingZeroCount)

        let recording = leadingZeros + speechSamples + trailingZeros
        let trimmed = RecordingCoordinator.trimSilence(from: recording)

        // Expected start: leadingZeroCount - paddingSamples = 16000 - 2400 = 13600
        // Expected end: leadingZeroCount + speechSamples.count + paddingSamples = 16000 + 800000 + 2400 = 818400
        let expectedCount = (speechSamples.count) + 2 * paddingSamples
        #expect(trimmed.count == expectedCount)

        // The speech samples must be preserved verbatim in the trimmed result at offset paddingSamples
        let extractedSpeech = Array(trimmed[paddingSamples..<(paddingSamples + speechSamples.count)])
        #expect(extractedSpeech.elementsEqual(speechSamples), "Speech samples must match original exactly")
    }

    /// Mixed long audio (65s) with quiet whispers, normal speech, and loud transients
    /// must be preserved in its entirety without dropping any audio.
    @Test func mixedLongLoudAndWhisperSectionsPreservedIntact() {
        let whisper1 = sineWave(durationSeconds: 15.0, amplitude: 0.002, frequency: 300.0)
        let normalSpeech = sineWave(durationSeconds: 15.0, amplitude: 0.025, frequency: 400.0)
        let transient1 = sineWave(durationSeconds: 0.2, amplitude: 0.8, frequency: 1000.0)
        let whisper2 = sineWave(durationSeconds: 15.0, amplitude: 0.0015, frequency: 350.0)
        let transient2 = sineWave(durationSeconds: 0.3, amplitude: 0.9, frequency: 1200.0)
        let trailingQuiet = sineWave(durationSeconds: 19.5, amplitude: 0.004, frequency: 450.0)

        let composite = whisper1 + normalSpeech + transient1 + whisper2 + transient2 + trailingQuiet
        let totalDuration = Double(composite.count) / Constants.sampleRate
        #expect(totalDuration == 65.0)

        let trimmed = RecordingCoordinator.trimSilence(from: composite)

        // Since all samples are non-zero real audio, zero-based trimming keeps 100% of the recording
        #expect(trimmed.count == composite.count, "Non-zero audio must never be discarded")
        #expect(trimmed.elementsEqual(composite), "Audio content must be untouched")
    }

    /// A loud transient must not cause surrounding quiet speech to be discarded.
    @Test func loudTransientPreservesSurroundingSpeech() {
        // 60s of quiet conversational speech (amplitude 0.015, RMS ~0.01)
        let quietSpeech = sineWave(durationSeconds: 60.0, amplitude: 0.015, frequency: 400.0)

        // 0.2s loud transient at second 60 (amplitude 0.8, RMS ~0.56)
        let loudTransient = sineWave(durationSeconds: 0.2, amplitude: 0.8, frequency: 1000.0)

        // 4.8s trailing quiet speech (amplitude 0.015)
        let trailingSpeech = sineWave(durationSeconds: 4.8, amplitude: 0.015, frequency: 400.0)

        let recording = quietSpeech + loudTransient + trailingSpeech
        let totalDuration = Double(recording.count) / Constants.sampleRate
        #expect(totalDuration == 65.0)

        let correctedTrimmed = RecordingCoordinator.trimSilence(from: recording)
        let correctedDuration = Double(correctedTrimmed.count) / Constants.sampleRate
        #expect(correctedDuration == 65.0, "Corrected trim must preserve full 65.0s recording")
        #expect(correctedTrimmed.elementsEqual(recording))
    }

    /// Short recordings under 2.0 seconds must not be trimmed at all.
    @Test func shortAudioUnderTwoSecondsNotTrimmed() {
        let samples = [Float](repeating: 0.0, count: 16000) + sineWave(durationSeconds: 0.5, amplitude: 0.02)
        let trimmed = RecordingCoordinator.trimSilence(from: samples)
        #expect(trimmed.count == samples.count)
    }

    /// Pure digital zeros must not crash and are returned unchanged.
    @Test func pureDigitalZerosHandledSafely() {
        let sampleRate = Int(Constants.sampleRate)
        let zeros = [Float](repeating: 0.0, count: 5 * sampleRate)
        let trimmed = RecordingCoordinator.trimSilence(from: zeros)
        #expect(trimmed.count == zeros.count)
    }
}
