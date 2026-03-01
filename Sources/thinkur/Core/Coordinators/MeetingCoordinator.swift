/// Dual-track meeting capture coordinator.
///
/// Records mic audio (AVAudioEngine) and system audio (ScreenCaptureKit) to separate WAV files.
/// The mic tap is the master clock: each audio callback reads from the SystemAudioCaptureManager's
/// ring buffer and writes both tracks synchronously. A timer task polls elapsed time, audio levels,
/// and system audio health. On stop, sends both tracks as separate Deepgram requests in parallel
/// for transcription and speaker diarization.

import Accelerate
@preconcurrency import AVFAudio
import AVFoundation
import Foundation
import os
import ScreenCaptureKit
import Synchronization

@MainActor
@Observable
final class MeetingCoordinator {
    // MARK: - Observable State

    enum MeetingProcessingState {
        case idle, processing, complete, failed
    }

    var isRecording = false
    var elapsedTime: TimeInterval = 0
    var currentAudioLevel: Float = 0
    var isSystemAudioActive = false
    var processingState: MeetingProcessingState = .idle
    var error: String?

    // MARK: - Dependencies

    private let settings: SettingsManager
    private let meetingService: MeetingService
    private let permissionManager: PermissionManager
    private let sharedState: SharedAppState

    // MARK: - Recording State

    // nonisolated(unsafe) allows deinit cleanup — these are still only
    // mutated from @MainActor contexts (startMeeting/stopAudioEngine).
    nonisolated(unsafe) private var audioEngine: AVAudioEngine?
    nonisolated(unsafe) private var configChangeObserver: NSObjectProtocol?
    private var micWriter: MeetingAudioWriter?
    private var systemWriter: MeetingAudioWriter?
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?
    private var recordingStartTime: Date?

    private var systemAudioManager: SystemAudioCaptureManager?

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Constants.sampleRate,
        channels: 1,
        interleaved: false
    )!

    init(
        settings: SettingsManager,
        meetingService: MeetingService,
        permissionManager: PermissionManager,
        sharedState: SharedAppState
    ) {
        self.settings = settings
        self.meetingService = meetingService
        self.permissionManager = permissionManager
        self.sharedState = sharedState
    }

    deinit {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timerTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()
    }

    // MARK: - Public API

    func startMeeting() async {
        guard !isRecording else { return }

        // Check API key first
        guard settings.hasDeepgramKey else {
            error = "Deepgram API key required. Set it up in Meetings."
            return
        }

        // Check microphone permission
        permissionManager.checkMicrophone()
        guard permissionManager.microphoneGranted else {
            await permissionManager.requestMicrophone()
            return
        }

        // Check screen recording permission (hard gate — required for system audio)
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            self.error = "Screen Recording permission required for meetings. Grant it in Settings \u{2192} Permissions."
            return
        }

        error = nil

        // Generate shared meeting ID for both track files
        let meetingId = UUID().uuidString

        // Create audio writers for both tracks
        do {
            micWriter = try MeetingAudioWriter(trackName: "mic", meetingId: meetingId)
            systemWriter = try MeetingAudioWriter(trackName: "system", meetingId: meetingId)
        } catch {
            self.error = "Failed to create audio files: \(error.localizedDescription)"
            return
        }

        // Start audio engine
        do {
            try startAudioEngine()
        } catch {
            self.error = "Failed to start audio capture: \(error.localizedDescription)"
            return
        }

        // Start system audio capture
        do {
            let sysAudio = SystemAudioCaptureManager()
            try await sysAudio.startCapture()
            systemAudioManager = sysAudio
            tapProcessor?.systemAudio = sysAudio
            isSystemAudioActive = true
            Logger.app.info("System audio capture enabled for meeting")
        } catch {
            Logger.app.warning("System audio capture failed: \(error)")
            isSystemAudioActive = false
            systemAudioManager = nil
        }

        // Reset state
        elapsedTime = 0
        recordingStartTime = Date()
        isRecording = true
        processingState = .idle
        sharedState.isMeetingActive = true

        // Start elapsed time timer + audio level polling + system audio health check
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { break }
                if let start = self.recordingStartTime {
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
                if let processor = self.tapProcessor {
                    self.currentAudioLevel = processor.currentAudioLevel
                }
                // Check if system audio capture dropped mid-meeting
                if self.isSystemAudioActive,
                   let sysAudio = self.systemAudioManager,
                   !sysAudio.isCapturing {
                    self.isSystemAudioActive = false
                    Logger.app.warning("System audio capture dropped mid-meeting")
                }
            }
        }

        Logger.app.info("Meeting recording started")
    }

    func stopMeeting() async {
        guard isRecording else { return }

        // Stop timer
        timerTask?.cancel()
        timerTask = nil

        // Stop system audio capture
        if let sysAudio = systemAudioManager {
            await sysAudio.stopCapture()
            systemAudioManager = nil
        }
        isSystemAudioActive = false

        // Stop audio engine (this nils tapProcessor)
        stopAudioEngine()

        // Finalize both WAV files
        let micPath = micWriter?.relativePath
        let sysPath = systemWriter?.relativePath
        let micFileURL = micWriter?.finalize()
        let sysFileURL = systemWriter?.finalize()
        micWriter = nil
        systemWriter = nil

        isRecording = false
        let duration = elapsedTime

        // Run final processing via Deepgram
        processingState = .processing

        guard let micURL = micFileURL, let sysURL = sysFileURL else {
            processingState = .failed
            error = "Audio files unavailable"
            sharedState.isMeetingActive = false
            return
        }

        do {
            let client = DeepgramClient()
            let result = try await client.transcribeMeeting(
                micURL: micURL, systemURL: sysURL, apiKey: settings.deepgramApiKey
            )

            let title = makeMeetingTitle()
            let record = try meetingService.saveMeeting(
                title: title,
                duration: duration,
                speakerCount: result.speakerCount,
                audioRelativePath: nil,
                micAudioRelativePath: micPath,
                systemAudioRelativePath: sysPath,
                segments: result.segments
            )

            processingState = .complete
            Logger.app.info("Meeting saved: \(String(format: "%.0f", duration))s, \(result.speakerCount) speakers, \(result.segments.count) segments")
        } catch {
            Logger.app.error("Meeting processing failed: \(error)")
            self.error = "Failed to process meeting: \(error.localizedDescription)"
            processingState = .failed
        }

        sharedState.isMeetingActive = false
        recordingStartTime = nil
    }

    // MARK: - Audio Engine

    private func startAudioEngine() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.invalidInputFormat
        }

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }

        guard let micW = micWriter, let sysW = systemWriter else {
            throw MeetingAudioWriterError.invalidFormat
        }

        let processor = AudioTapProcessor(
            converter: conv,
            targetFormat: targetFormat,
            micWriter: micW,
            systemWriter: sysW
        )
        tapProcessor = processor

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            processor.process(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            tapProcessor = nil
            throw error
        }
        audioEngine = engine

        // Handle audio device changes (headphones plugged/unplugged, device switch)
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleConfigurationChange()
            }
        }
    }

    private func stopAudioEngine() {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()   // Release audio hardware before dealloc
        audioEngine = nil
        tapProcessor = nil
    }

    /// Audio processing helper that runs on the audio thread.
    /// Writes mic and system audio to separate WAV files.
    private class AudioTapProcessor {
        let converter: AVAudioConverter
        let targetFormat: AVAudioFormat
        let micWriter: MeetingAudioWriter
        let systemWriter: MeetingAudioWriter
        var systemAudio: SystemAudioCaptureManager?
        private let _audioLevel = Mutex<Float>(0)
        var currentAudioLevel: Float { _audioLevel.withLock { $0 } }

        init(converter: AVAudioConverter, targetFormat: AVAudioFormat, micWriter: MeetingAudioWriter, systemWriter: MeetingAudioWriter, systemAudio: SystemAudioCaptureManager? = nil) {
            self.converter = converter
            self.targetFormat = targetFormat
            self.micWriter = micWriter
            self.systemWriter = systemWriter
            self.systemAudio = systemAudio
        }

        func process(_ buffer: AVAudioPCMBuffer) {
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

            // Compute RMS audio level from mic
            var micRms: Float = 0
            vDSP_rmsqv(channelData[0], 1, &micRms, vDSP_Length(frameLength))

            let micSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

            // Write mic samples to mic track
            micWriter.appendSamples(micSamples)

            // Write system audio to system track (separate file, no mixing)
            var sysRms: Float = 0
            if let systemAudio, systemAudio.isCapturing {
                let sysSamples = systemAudio.readSamples(count: frameLength)
                systemWriter.appendSamples(sysSamples)
                sysSamples.withUnsafeBufferPointer { buf in
                    vDSP_rmsqv(buf.baseAddress!, 1, &sysRms, vDSP_Length(sysSamples.count))
                }
            }

            // Show whichever source is louder
            let combinedLevel = max(micRms, sysRms)
            _audioLevel.withLock { $0 = min(combinedLevel * 12.0, 1.0) }
        }
    }

    private var tapProcessor: AudioTapProcessor?

    // MARK: - Configuration Change

    private func handleConfigurationChange() {
        guard isRecording, let engine = audioEngine else { return }
        Logger.app.info("Meeting audio configuration changed — rebuilding pipeline")

        engine.inputNode.removeTap(onBus: 0)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0,
              let conv = AVAudioConverter(from: inputFormat, to: targetFormat),
              let micW = micWriter, let sysW = systemWriter else {
            Logger.app.error("Meeting config change: invalid format — stopping meeting")
            Task { await stopMeeting() }
            return
        }

        let processor = AudioTapProcessor(
            converter: conv,
            targetFormat: targetFormat,
            micWriter: micW,
            systemWriter: sysW,
            systemAudio: systemAudioManager
        )
        tapProcessor = processor

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            processor.process(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            Logger.app.info("Meeting audio pipeline rebuilt at \(inputFormat.sampleRate)Hz after config change")
        } catch {
            Logger.app.error("Failed to restart meeting engine after config change: \(error)")
            inputNode.removeTap(onBus: 0)
            tapProcessor = nil
            Task { await stopMeeting() }
        }
    }

    // MARK: - Helpers

    private func makeMeetingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Meeting \u{2014} \(formatter.string(from: Date()))"
    }
}
