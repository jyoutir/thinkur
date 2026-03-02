# Meeting Transcription System

## Overview

thinkur supports live meeting transcription with speaker diarization. It captures both microphone and system audio simultaneously, transcribes them via Deepgram, and merges the results into a speaker-attributed transcript.

## Architecture

### Dual-Track Recording

Two independent audio streams run in parallel during a meeting:

1. **Microphone track** — `AVAudioEngine` captures the local user's mic input (same pipeline as dictation, 16kHz mono Float32).
2. **System audio track** — `ScreenCaptureKit` captures system-wide audio output (remote participants in Zoom/Meet/Teams/etc.).

Each track accumulates audio buffers independently. When the meeting ends, both tracks are sent to Deepgram for transcription.

### Transcription (Deepgram)

Two separate Deepgram API requests are made in parallel:

| Track | Diarization | Reason |
|-------|-------------|--------|
| Mic (local) | **Off** | Only one speaker — the local user |
| System audio | **On** | Multiple remote participants need separation |

Both requests use Deepgram's `nova-2` model with `punctuate`, `smart_format`, and `utterances` enabled.

### Speaker Attribution

After both transcriptions return, results are merged chronologically:

- **Mic utterances** → labeled `"You"` (the local user)
- **System utterances** → labeled `"Speaker 1"`, `"Speaker 2"`, etc. (Deepgram's diarization assigns speaker IDs)

Speaker names can be renamed in the UI after the meeting.

### Empty System Audio

If no system audio is captured (e.g., solo recording or system audio permission denied), the meeting proceeds with mic-only transcription. The system track is silently skipped — no error is shown.

## Data Flow

```
Meeting Start
├── AVAudioEngine → mic buffers (local user)
└── ScreenCaptureKit → system buffers (remote participants)

Meeting Stop
├── mic buffers → Deepgram (no diarization) → "You" utterances
└── system buffers → Deepgram (diarization) → "Speaker N" utterances

Merge by timestamp → final transcript with speaker labels
```

## Key Implementation Details

- Audio buffers are accumulated in memory during recording (not streamed to Deepgram in real-time)
- Both Deepgram requests run concurrently via `async let`
- Utterance timestamps are relative to recording start, enabling accurate chronological merge
- System audio capture requires Screen Recording permission on macOS
- Meeting transcripts are stored via SwiftData alongside dictation history
