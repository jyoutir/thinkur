import Foundation
@testable import thinkur

final class MockAudioCapturing: AudioCapturing {
    var isCapturing = false
    var currentAudioLevel: Float = 0.0
    var samplesToReturn: [Float] = []

    func startCapture() throws {
        isCapturing = true
    }

    func stopCapture() -> [Float] {
        isCapturing = false
        return samplesToReturn
    }
}
