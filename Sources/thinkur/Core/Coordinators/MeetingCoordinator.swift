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

    var isRecording = false
    var elapsedTime: TimeInterval = 0
    var liveSegments: [AttributedSegment] = []
    var currentAudioLevel: Float = 0
    var speakerCount: Int = 0
    var isSystemAudioActive = false
    var isDiarizerLoading = false
    var diarizerLoadingMessage = ""
    var error: String?

    // MARK: - Dependencies

    private let transcriptionEngine: ParakeetTranscriptionEngine
    private let meetingService: MeetingService
    private let permissionManager: PermissionManager
    private let sharedState: SharedAppState

    // MARK: - Recording State

    // nonisolated(unsafe) allows deinit cleanup — these are still only
    // mutated from @MainActor contexts (startMeeting/stopAudioEngine).
    nonisolated(unsafe) private var audioEngine: AVAudioEngine?
    nonisolated(unsafe) private var configChangeObserver: NSObjectProtocol?
    private var audioWriter: MeetingAudioWriter?
    private var pipeline: MeetingTranscriptionPipeline?
    private let bufferQueue = DispatchQueue(label: "com.thinkur.meetingBuffer")
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?
    nonisolated(unsafe) private var chunkTask: Task<Void, Never>?
    private var recordingStartTime: Date?

    /// ~30 seconds of audio at 16kHz
    private let chunkSizeInSamples = Int(30.0 * Constants.sampleRate)

    private var systemAudioManager: SystemAudioCaptureManager?

    // Diarizer state (loaded once, reused)
    private var diarizerManager: DiarizerManager?
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
        sharedState: SharedAppState
    ) {
        self.transcriptionEngine = transcriptionEngine
        self.meetingService = meetingService
        self.permissionManager = permissionManager
        self.sharedState = sharedState
    }

    deinit {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timerTask?.cancel()
        chunkTask?.cancel()
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
        // Use ScreenCaptureKit directly for a reliable async check
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

        // Load diarizer models if needed
        if diarizerManager == nil {
            do {
                let cacheDir = Constants.appSupportDirectory
                    .appendingPathComponent("diarizer", isDirectory: true)
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

                let models = try await DiarizerModels.download(to: cacheDir)
                let manager = DiarizerManager()
                manager.initialize(models: models)
                diarizerManager = manager
                Logger.app.info("Diarizer models loaded for meeting mode")
            } catch {
                self.error = "Failed to prepare meeting: \(error.localizedDescription)"
                isDiarizerLoading = false
                return
            }
        }

        // Load offline diarizer models for post-recording polish
        if offlineDiarizer == nil {
            do {
                let offline = OfflineDiarizerManager()
                let offlineCacheDir = Constants.appSupportDirectory
                    .appendingPathComponent("offline-diarizer", isDirectory: true)
                try await offline.prepareModels(directory: offlineCacheDir)
                offlineDiarizer = offline
                Logger.app.info("Offline diarizer models loaded for meeting polish")
            } catch {
                Logger.app.warning("Offline diarizer failed to load, polish will be skipped: \(error)")
                // Non-fatal — live segments will still be used
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

        // Create pipeline
        pipeline = MeetingTranscriptionPipeline(
            asrManager: asrManagerForMeeting!,
            diarizerManager: diarizerManager!
        )

        // Create audio writer
        do {
            audioWriter = try MeetingAudioWriter()
        } catch {
            self.error = "Failed to create audio file: \(error.localizedDescription)"
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
        liveSegments = []
        speakerCount = 0
        elapsedTime = 0
        recordingStartTime = Date()
        isRecording = true
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

        // Start chunk processing loop
        chunkTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { break }
                await self.processCurrentChunk()
            }
        }

        Logger.app.info("Meeting recording started")
    }

    func stopMeeting() async {
        guard isRecording else { return }

        // Stop timers
        timerTask?.cancel()
        timerTask = nil
        chunkTask?.cancel()
        chunkTask = nil

        // Process remaining buffer before stopping the engine
        await processCurrentChunk()

        // Stop system audio capture
        if let sysAudio = systemAudioManager {
            await sysAudio.stopCapture()
            systemAudioManager = nil
        }
        isSystemAudioActive = false

        // Stop audio engine (this nils tapProcessor)
        stopAudioEngine()

        // Finalize audio file
        let audioPath = audioWriter?.relativePath
        let audioFileURL = audioWriter?.finalize()
        audioWriter = nil

        // Re-process with offline pipeline for better speaker attribution
        if let offlineDiarizer, let audioURL = audioFileURL {
            do {
                let offlineResult = try await offlineDiarizer.process(audioURL)

                if let asrManager = asrManagerForMeeting {
                    let audioData = try loadAudioSamples(from: audioURL)
                    let asrResult = try await asrManager.transcribe(audioData, source: .microphone)

                    if let timings = asrResult.tokenTimings, !timings.isEmpty,
                       !offlineResult.segments.isEmpty {
                        let polished = MeetingTranscriptionPipeline.mergeTimingsWithSpeakers(
                            tokenTimings: timings,
                            speakerSegments: offlineResult.segments,
                            chunkStartTime: 0
                        )
                        if !polished.isEmpty {
                            liveSegments = polished
                            Logger.app.info("Meeting polished with offline diarization: \(polished.count) segments")
                        }
                    }
                }
            } catch {
                Logger.app.error("Offline polish failed, keeping live segments: \(error)")
            }
        }

        // Collect unique speakers
        let uniqueSpeakers = Set(liveSegments.map(\.speakerId))
        speakerCount = uniqueSpeakers.count

        // Save to SwiftData
        let duration = elapsedTime
        let segments = liveSegments
        let title = makeMeetingTitle()

        do {
            _ = try meetingService.saveMeeting(
                title: title,
                duration: duration,
                speakerCount: uniqueSpeakers.count,
                audioRelativePath: audioPath,
                segments: segments
            )
        } catch {
            Logger.app.error("Failed to save meeting: \(error)")
        }

        isRecording = false
        sharedState.isMeetingActive = false
        recordingStartTime = nil
        Logger.app.info("Meeting recording stopped: \(String(format: "%.0f", duration))s, \(uniqueSpeakers.count) speakers")
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

        guard let writer = audioWriter else {
            throw MeetingAudioWriterError.invalidFormat
        }

        let processor = AudioTapProcessor(
            converter: conv,
            targetFormat: targetFormat,
            audioWriter: writer,
            bufferQueue: bufferQueue
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
    /// Captures necessary references to avoid main actor access.
    private class AudioTapProcessor {
        let converter: AVAudioConverter
        let targetFormat: AVAudioFormat
        let audioWriter: MeetingAudioWriter
        let bufferQueue: DispatchQueue
        var systemAudio: SystemAudioCaptureManager?
        var chunkBuffer: [Float] = []
        private let _audioLevel = Mutex<Float>(0)
        var currentAudioLevel: Float { _audioLevel.withLock { $0 } }

        init(converter: AVAudioConverter, targetFormat: AVAudioFormat, audioWriter: MeetingAudioWriter, bufferQueue: DispatchQueue, systemAudio: SystemAudioCaptureManager? = nil) {
            self.converter = converter
            self.targetFormat = targetFormat
            self.audioWriter = audioWriter
            self.bufferQueue = bufferQueue
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

            // Compute RMS audio level
            var rms: Float = 0
            vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
            _audioLevel.withLock { $0 = min(rms * 12.0, 1.0) }

            var samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

            // Mix in system audio if available
            if let systemAudio, systemAudio.isCapturing {
                var sysSamples = systemAudio.readSamples(count: frameLength)
                vDSP_vadd(samples, 1, sysSamples, 1, &samples, 1, vDSP_Length(frameLength))
            }

            // Write to disk (thread-safe)
            audioWriter.appendSamples(samples)

            // Append to chunk buffer
            bufferQueue.sync {
                chunkBuffer.append(contentsOf: samples)
            }
        }

        func drainChunkBuffer() -> [Float] {
            bufferQueue.sync {
                let chunk = chunkBuffer
                chunkBuffer.removeAll(keepingCapacity: true)
                return chunk
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
              let writer = audioWriter else {
            Logger.app.error("Meeting config change: invalid format — stopping meeting")
            Task { await stopMeeting() }
            return
        }

        let processor = AudioTapProcessor(
            converter: conv,
            targetFormat: targetFormat,
            audioWriter: writer,
            bufferQueue: bufferQueue,
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

    // MARK: - Chunk Processing

    private func processCurrentChunk() async {
        guard let processor = tapProcessor else { return }

        // Update audio level on main actor
        currentAudioLevel = processor.currentAudioLevel

        let samples = processor.drainChunkBuffer()
        guard !samples.isEmpty, let pipeline else { return }

        let chunkStartTime = elapsedTime - Double(samples.count) / Constants.sampleRate

        let segments = await pipeline.processChunk(samples, chunkStartTime: max(0, chunkStartTime))

        if !segments.isEmpty {
            liveSegments.append(contentsOf: segments)
            let uniqueSpeakers = Set(liveSegments.map(\.speakerId))
            speakerCount = uniqueSpeakers.count
        }
    }

    // MARK: - Helpers

    private func loadAudioSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.sampleRate,
            channels: 1,
            interleaved: false
        )!
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw MeetingAudioWriterError.invalidFormat
        }
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }

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
