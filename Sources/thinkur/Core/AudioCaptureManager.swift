import Accelerate
import AVFAudio
import AVFoundation
import os
import Synchronization

final class AudioCaptureManager: AudioCapturing {
    private var audioEngine: AVAudioEngine?
    private var tappedInputNode: AVAudioInputNode?
    private var audioBuffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "com.thinkur.audioBuffer")
    private let targetFormat: AVAudioFormat

    private(set) var isCapturing = false
    private var configChangeObserver: NSObjectProtocol?

    /// Current audio level 0.0–1.0 (RMS), updated every buffer callback (~23ms at 1024/44.1kHz).
    /// Thread-safe: written on audio callback thread, read on main thread.
    private let _audioLevel = Mutex<Float>(0)
    var currentAudioLevel: Float { _audioLevel.withLock { $0 } }

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.sampleRate,
            channels: 1,
            interleaved: false
        )!
    }

    deinit {
        stopAudioEngine()
    }

    func startCapture() throws {
        guard !isCapturing else { return }

        // Defense-in-depth: refuse to start if microphone permission is not granted,
        // even if callers forgot to check.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            Logger.audio.error("Microphone permission not granted — refusing to start capture")
            throw AudioCaptureError.microphonePermissionDenied
        }

        bufferQueue.sync {
            audioBuffer.removeAll(keepingCapacity: true)
            audioBuffer.reserveCapacity(Int(Constants.sampleRate) * 30)
        }

        do {
            try startAudioEngine()
        } catch {
            stopAudioEngine()
            throw error
        }
    }

    private func startAudioEngine() throws {
        let engine = AVAudioEngine()
        audioEngine = engine

        // Observe before touching the input node or starting the engine: opening
        // a Bluetooth microphone can itself change the hardware configuration.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self, weak engine] _ in
            // Return to Core Audio immediately; rebuild outside its notification.
            Task { @MainActor [weak self, weak engine] in
                guard let self, let engine, self.audioEngine === engine else { return }
                self.handleConfigurationChange()
            }
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            Logger.audio.error("Invalid microphone input format: \(inputFormat)")
            throw AudioCaptureError.invalidInputFormat
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            Logger.audio.error("Failed to create audio converter from \(inputFormat) to \(self.targetFormat)")
            throw AudioCaptureError.converterCreationFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer, converter: converter)
        }
        tappedInputNode = inputNode

        engine.prepare()
        try engine.start()
        isCapturing = true

        Logger.audio.info("Audio capture started at \(inputFormat.sampleRate)Hz, converting to \(Constants.sampleRate)Hz")
    }

    /// Release resources even when startup or route recovery already failed.
    private func stopAudioEngine() {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
        let engine = audioEngine
        audioEngine = nil // Invalidate notifications already queued for this engine.
        engine?.stop()
        tappedInputNode?.removeTap(onBus: 0)
        tappedInputNode = nil
        engine?.reset()
        isCapturing = false
        _audioLevel.withLock { $0 = 0 }
    }

    func stopCapture() -> [Float] {
        stopAudioEngine()

        // Always drain — preserves partial audio after config change failures
        let samples = bufferQueue.sync {
            var result: [Float] = []
            swap(&result, &audioBuffer)
            return result
        }

        let duration = Double(samples.count) / Constants.sampleRate
        Logger.audio.info("Audio capture stopped: \(samples.count) samples (\(String(format: "%.1f", duration))s)")
        return samples
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {

        let ratio = Constants.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else { return }

        var inputConsumed = false
        let status = converter.convert(to: convertedBuffer, error: nil) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error,
              let channelData = convertedBuffer.floatChannelData else { return }

        let frameLength = Int(convertedBuffer.frameLength)

        // Vectorized RMS via Accelerate (replaces reduce-based calculation)
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
        // Increased gain from 6.0 to 12.0 for better whisper sensitivity
        let normalized = min(rms * 12.0, 1.0)
        _audioLevel.withLock { $0 = normalized }

        bufferQueue.sync {
            audioBuffer.append(contentsOf: UnsafeBufferPointer(
                start: channelData[0],
                count: frameLength
            ))
        }
    }

    // MARK: - Configuration Change

    private func handleConfigurationChange() {
        guard isCapturing else { return }
        Logger.audio.info("Audio configuration changed — rebuilding audio pipeline")

        // Keep accumulated samples, but discard the old hardware graph and its
        // observer. Queued notifications from that graph cannot affect the new one.
        stopAudioEngine()
        do {
            try startAudioEngine()
        } catch {
            Logger.audio.error("Failed to restart engine after config change: \(error)")
            stopAudioEngine()
        }
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case microphonePermissionDenied
    case invalidInputFormat
    case converterCreationFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required to record audio"
        case .invalidInputFormat:
            return "Microphone input format is invalid"
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        }
    }
}
