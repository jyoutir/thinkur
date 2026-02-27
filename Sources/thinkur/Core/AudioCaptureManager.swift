import Accelerate
import AVFAudio
import AVFoundation
import os
import Synchronization

final class AudioCaptureManager: AudioCapturing {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "com.thinkur.audioBuffer")
    private var converter: AVAudioConverter?
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
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if isCapturing {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            audioEngine.reset()
        }
    }

    func startCapture() throws {
        guard !isCapturing else { return }

        // Defense-in-depth: refuse to start if microphone permission is not granted,
        // even if callers forgot to check.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            Logger.audio.error("Microphone permission not granted — refusing to start capture")
            throw AudioCaptureError.microphonePermissionDenied
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            Logger.audio.error("Invalid input format: sample rate is 0")
            throw AudioCaptureError.invalidInputFormat
        }

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            Logger.audio.error("Failed to create audio converter from \(inputFormat) to \(self.targetFormat)")
            throw AudioCaptureError.converterCreationFailed
        }
        converter = conv

        bufferQueue.sync {
            audioBuffer.removeAll(keepingCapacity: true)
            audioBuffer.reserveCapacity(Int(Constants.sampleRate) * 30)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            converter = nil
            throw error
        }
        isCapturing = true

        // Handle audio device changes (headphones plugged/unplugged, device switch)
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }

        Logger.audio.info("Audio capture started at \(inputFormat.sampleRate)Hz, converting to \(Constants.sampleRate)Hz")
    }

    func stopCapture() -> [Float] {
        guard isCapturing else { return [] }

        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()   // Release audio hardware (audio units + aggregate device)
        converter = nil       // Drop stale converter (will be recreated on next start)
        isCapturing = false
        _audioLevel.withLock { $0 = 0 }

        let samples = bufferQueue.sync {
            var result: [Float] = []
            swap(&result, &audioBuffer)
            return result
        }

        let duration = Double(samples.count) / Constants.sampleRate
        Logger.audio.info("Audio capture stopped: \(samples.count) samples (\(String(format: "%.1f", duration))s)")
        return samples
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

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

        // Remove stale tap from old configuration
        audioEngine.inputNode.removeTap(onBus: 0)

        // Re-read format from new device
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0,
              let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            Logger.audio.error("Configuration change: invalid format or converter — stopping capture")
            isCapturing = false
            _audioLevel.withLock { $0 = 0 }
            return
        }
        converter = conv

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            Logger.audio.info("Audio pipeline rebuilt at \(inputFormat.sampleRate)Hz after config change")
        } catch {
            Logger.audio.error("Failed to restart engine after config change: \(error)")
            inputNode.removeTap(onBus: 0)
            converter = nil
            isCapturing = false
            _audioLevel.withLock { $0 = 0 }
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
