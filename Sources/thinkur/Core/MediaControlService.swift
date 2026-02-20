import CoreAudio
import os

enum MediaControlService {
    private static var savedVolume: Float = -1
    private static var didDim = false

    /// Dims system volume to 40% of its current level.
    static func dimPlayback() {
        guard let volume = getSystemVolume(), volume > 0 else { return }
        savedVolume = volume
        setSystemVolume(volume * 0.4)
        didDim = true
    }

    /// Restores system volume to saved level if we dimmed it.
    static func restorePlayback() {
        guard didDim else { return }
        didDim = false
        let volume = savedVolume
        savedVolume = -1
        guard volume >= 0 else { return }
        setSystemVolume(volume)
    }

    // MARK: - CoreAudio Helpers

    private static func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func getSystemVolume() -> Float? {
        guard let deviceID = getDefaultOutputDevice() else { return nil }
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)

        // Try master channel first, then fall back to channel 1
        for channel: UInt32 in [kAudioObjectPropertyElementMain, 1] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
            if status == noErr { return volume }
        }
        return nil
    }

    private static func setSystemVolume(_ volume: Float) {
        guard let deviceID = getDefaultOutputDevice() else { return }
        var vol = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)

        // Try master channel first
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
        if status == noErr { return }

        // Fall back to setting each channel individually
        for channel: UInt32 in [1, 2] {
            address.mElement = channel
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
        }
    }
}
