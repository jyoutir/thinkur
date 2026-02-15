import Foundation

@MainActor
protocol Transcribing: AnyObject {
    var isLoaded: Bool { get }
    var isLoading: Bool { get }
    var loadingMessage: String { get }
    var errorMessage: String? { get }
    var lastWordTimings: [WordTimingInfo] { get }
    func loadModel() async
    func transcribe(audioSamples: [Float]) async -> String?
}
