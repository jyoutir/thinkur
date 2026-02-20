import Foundation
import os

enum MediaControlService {
    private static var savedMusicVolume: Int = -1
    private static var savedSpotifyVolume: Int = -1
    private static var didDim = false

    /// Dims music volume to 40% of its current level in common media apps (Music, Spotify).
    static func dimPlayback() {
        let script = """
        set result to ""
        tell application "System Events"
            set musicRunning to (exists process "Music")
            set spotifyRunning to (exists process "Spotify")
        end tell

        if musicRunning then
            tell application "Music"
                if player state is playing then
                    set vol to sound volume
                    set result to "music:" & vol
                    set sound volume to (vol * 40 / 100)
                end if
            end tell
        end if

        if spotifyRunning then
            tell application "Spotify"
                if player state is playing then
                    set vol to sound volume
                    if result is not "" then
                        set result to result & ","
                    end if
                    set result to result & "spotify:" & vol
                    set sound volume to (vol * 40 / 100)
                end if
            end tell
        end if

        return result
        """
        runAppleScriptReturningString(script) { result in
            guard let result, !result.isEmpty else { return }
            // Parse "music:80" or "spotify:65" or "music:80,spotify:65"
            for component in result.split(separator: ",") {
                let parts = component.split(separator: ":")
                guard parts.count == 2, let vol = Int(parts[1]) else { continue }
                if parts[0] == "music" {
                    savedMusicVolume = vol
                } else if parts[0] == "spotify" {
                    savedSpotifyVolume = vol
                }
            }
            didDim = true
        }
    }

    /// Restores music volume to saved levels if we dimmed it.
    static func restorePlayback() {
        guard didDim else { return }
        didDim = false
        let musicVol = savedMusicVolume
        let spotifyVol = savedSpotifyVolume
        savedMusicVolume = -1
        savedSpotifyVolume = -1

        var scriptParts: [String] = []
        scriptParts.append("""
        tell application "System Events"
            set musicRunning to (exists process "Music")
            set spotifyRunning to (exists process "Spotify")
        end tell
        """)

        if musicVol >= 0 {
            scriptParts.append("""
            if musicRunning then
                tell application "Music"
                    set sound volume to \(musicVol)
                end tell
            end if
            """)
        }
        if spotifyVol >= 0 {
            scriptParts.append("""
            if spotifyRunning then
                tell application "Spotify"
                    set sound volume to \(spotifyVol)
                end tell
            end if
            """)
        }

        guard scriptParts.count > 1 else { return }
        runAppleScript(scriptParts.joined(separator: "\n"))
    }

    private static func runAppleScript(_ source: String) {
        Task.detached {
            let appleScript = NSAppleScript(source: source)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            if let error {
                Logger.app.debug("AppleScript error: \(error)")
            }
        }
    }

    private static func runAppleScriptReturningString(_ source: String, completion: @MainActor @escaping (String?) -> Void) {
        Task.detached {
            let appleScript = NSAppleScript(source: source)
            var error: NSDictionary?
            let descriptor = appleScript?.executeAndReturnError(&error)
            if let error {
                Logger.app.debug("AppleScript error: \(error)")
            }
            let result = descriptor?.stringValue
            await completion(result)
        }
    }
}
