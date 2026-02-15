import Foundation

protocol AudioCapturing: AnyObject {
    var isCapturing: Bool { get }
    var currentAudioLevel: Float { get }
    func startCapture() throws
    func stopCapture() -> [Float]
}
