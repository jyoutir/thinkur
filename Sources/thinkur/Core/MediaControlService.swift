import CoreAudio
import os

enum MediaControlService {
    private static let savedVolumeKey = "com.thinkur.mediaControl.savedVolume"
    private static let didDimKey = "com.thinkur.mediaControl.didDim"

    /// Serial queue for CoreAudio volume calls — AudioObjectSetPropertyData blocks 10-100ms.
    private static let audioQueue = DispatchQueue(label: "com.thinkur.mediaControl", qos: .userInitiated)

    /// Persisted so volume can be restored after a crash.
    private static var savedVolume: Float? {
        get {
            guard UserDefaults.standard.object(forKey: savedVolumeKey) != nil else { return nil }
            return UserDefaults.standard.float(forKey: savedVolumeKey)
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: savedVolumeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: savedVolumeKey)
            }
        }
    }

    private static var didDim: Bool {
        get { UserDefaults.standard.bool(forKey: didDimKey) }
        set { UserDefaults.standard.set(newValue, forKey: didDimKey) }
    }

    /// Dims system volume to 40% of its current level.
    /// Dispatches to background queue so CoreAudio calls don't block the main thread.
    static func dimPlayback() {
        audioQueue.async {
            guard let volume = getSystemVolume(), volume > 0 else { return }
            savedVolume = volume
            setSystemVolume(volume * 0.4)
            didDim = true
        }
    }

    /// Restores system volume to saved level if we dimmed it.
    /// Dispatches to background queue so CoreAudio calls don't block the main thread.
    static func restorePlayback() {
        audioQueue.async {
            guard didDim else { return }
            didDim = false
            let volume = savedVolume
            savedVolume = nil
            guard let volume, volume >= 0 else { return }
            setSystemVolume(volume)
        }
    }

    /// Call on launch to restore volume if the app crashed while dimmed.
    static func restoreIfNeeded() {
        audioQueue.async {
            guard didDim, let volume = savedVolume, volume >= 0 else { return }
            Logger.app.info("Restoring volume after previous crash (saved: \(volume))")
            didDim = false
            savedVolume = nil
            setSystemVolume(volume)
        }
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
