## Unreleased

- Fixed dictation audio cleanup after failed microphone/device changes so recording can be started again.
- Handle audio configuration changes during startup and ignore stale notifications from previous recording sessions.
- Preserve quiet dictation around loud sounds by trimming only digital-zero padding, not estimating silence from peak volume.
- Keep recent transcription history visible when browsing another calendar month.
- Keep implicit number/ordinal sequences as prose; preserve spoken numbering in explicit lists and ordinal words within list items.
- Format compound ordinals such as "twenty third" as "23rd" instead of a fraction.
- Isolate recording tests from system audio controls so they cannot dim the Mac's output.

## What's New

thinkur is now completely free and open-source!

- Removed all licensing — no word limits, no paywall, completely free
- Open-source on GitHub: https://github.com/jyoutir/thinkur
- Removed telemetry tracking for license events
- Support moved to GitHub Issues
