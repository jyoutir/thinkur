import Foundation
import os

enum MediaControlService {
    private static var wasPlaying = false

    /// Pauses music playback in common media apps (Music, Spotify).
    static func pausePlayback() {
        // Check if any media app is playing and pause it
        let script = """
        tell application "System Events"
            set musicRunning to (exists process "Music")
            set spotifyRunning to (exists process "Spotify")
        end tell

        set didPause to false
        if musicRunning then
            tell application "Music"
                if player state is playing then
                    pause
                    set didPause to true
                end if
            end tell
        end if

        if spotifyRunning and not didPause then
            tell application "Spotify"
                if player state is playing then
                    pause
                end if
            end tell
        end if
        """
        runAppleScript(script)
        wasPlaying = true
    }

    /// Resumes music playback if it was paused by us.
    static func resumePlayback() {
        guard wasPlaying else { return }
        wasPlaying = false

        let script = """
        tell application "System Events"
            set musicRunning to (exists process "Music")
            set spotifyRunning to (exists process "Spotify")
        end tell

        if musicRunning then
            tell application "Music"
                if player state is paused then
                    play
                end if
            end tell
        else if spotifyRunning then
            tell application "Spotify"
                if player state is paused then
                    play
                end if
            end tell
        end if
        """
        runAppleScript(script)
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
}
