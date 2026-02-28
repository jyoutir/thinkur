import Accelerate
@preconcurrency import AVFAudio
import AVFoundation
import FluidAudio
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
    var isDiarizerLoading = false
    var diarizerLoadingMessage = ""
    var processingState: MeetingProcessingState = .idle
    var error: String?

    // MARK: - Dependencies

    private let transcriptionEngine: ParakeetTranscriptionEngine
    private let meetingService: MeetingService
    private let permissionManager: PermissionManager
    private let sharedState: SharedAppState
    private let speakerProfileService: SpeakerProfileService

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

    // Models (loaded once, reused)
    private var offlineDiarizer: OfflineDiarizerManager?
    private var asrManagerForMeeting: AsrManager?

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Constants.sampleRate,
        channels: 1,
        interleaved: false
    )!

    init(
        transcriptionEngine: ParakeetTranscriptionEngine,
        meetingService: MeetingService,
        permissionManager: PermissionManager,
        sharedState: SharedAppState,
        speakerProfileService: SpeakerProfileService
    ) {
        self.transcriptionEngine = transcriptionEngine
        self.meetingService = meetingService
        self.permissionManager = permissionManager
        self.sharedState = sharedState
        self.speakerProfileService = speakerProfileService
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

        // Ensure ASR model is loaded
        guard transcriptionEngine.isLoaded else {
            error = "Voice engine not ready yet"
            return
        }

        error = nil
        isDiarizerLoading = true
        diarizerLoadingMessage = "Preparing meeting models"

        // Load offline diarizer models
        if offlineDiarizer == nil {
            do {
                let offline = OfflineDiarizerManager()
                let offlineCacheDir = Constants.appSupportDirectory
                    .appendingPathComponent("offline-diarizer", isDirectory: true)
                try await offline.prepareModels(directory: offlineCacheDir)
                offlineDiarizer = offline
                Logger.app.info("Offline diarizer models loaded for meeting")
            } catch {
                Logger.app.warning("Offline diarizer failed to load, remote speakers won't be separated: \(error)")
                // Non-fatal — all remote audio will be assigned to "remote-1"
            }
        }

        // Create a dedicated ASR manager for meetings
        if asrManagerForMeeting == nil {
            do {
                let cacheDir = ParakeetTranscriptionEngine.meetingModelCacheDir
                let models = try await AsrModels.downloadAndLoad(to: cacheDir, version: .v3)
                let manager = AsrManager()
                try await manager.initialize(models: models)
                asrManagerForMeeting = manager
                Logger.app.info("Dedicated ASR manager loaded for meetings")
            } catch {
                self.error = "Failed to load transcription engine: \(error.localizedDescription)"
                isDiarizerLoading = false
                return
            }
        }

        isDiarizerLoading = false
        diarizerLoadingMessage = ""

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

        // Start elapsed time timer + audio level polling
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

        // Run final processing
        processingState = .processing

        guard let micURL = micFileURL, let sysURL = sysFileURL,
              let asrManager = asrManagerForMeeting else {
            processingState = .failed
            error = "Audio files or ASR engine unavailable"
            sharedState.isMeetingActive = false
            return
        }

        let processor = MeetingFinalProcessor(
            asrManager: asrManager,
            offlineDiarizer: offlineDiarizer
        )

        do {
            let result = try await processor.process(
                micURL: micURL,
                systemURL: sysURL,
                duration: duration
            )

            // Match speakers against known profiles
            let matches = try speakerProfileService.matchSpeakers(embeddings: result.speakerEmbeddings)
            let profileNames = speakerProfileService.applyProfileNames(matches: matches)
            try speakerProfileService.updateProfiles(embeddings: result.speakerEmbeddings, matches: matches)

            let title = makeMeetingTitle()
            let record = try meetingService.saveMeeting(
                title: title,
                duration: duration,
                speakerCount: result.speakerCount,
                audioRelativePath: nil,
                micAudioRelativePath: micPath,
                systemAudioRelativePath: sysPath,
                speakerEmbeddings: result.speakerEmbeddings,
                segments: result.segments
            )

            // Apply known speaker names from profiles
            for (speakerId, name) in profileNames {
                try meetingService.updateSpeakerName(meeting: record, speakerId: speakerId, name: name)
            }

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
            var rms: Float = 0
            vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
            _audioLevel.withLock { $0 = min(rms * 12.0, 1.0) }

            let micSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

            // Write mic samples to mic track
            micWriter.appendSamples(micSamples)

            // Write system audio to system track (separate file, no mixing)
            if let systemAudio, systemAudio.isCapturing {
                let sysSamples = systemAudio.readSamples(count: frameLength)
                systemWriter.appendSamples(sysSamples)
            }
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

// Extension to expose model cache dir for meeting's dedicated ASR
extension ParakeetTranscriptionEngine {
    nonisolated static var meetingModelCacheDir: URL {
        let dir = Constants.appSupportDirectory.appendingPathComponent("parakeet-v3", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
