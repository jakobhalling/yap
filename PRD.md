# Yap — Product Requirements Document

## Overview

Yap is a cross-platform (macOS & Windows) system tray application that enables voice-driven text input into any application. The user activates Yap with a global shortcut, speaks, sees a real-time streaming transcript, optionally processes it through an LLM with customizable prompt profiles, and pastes the result into the currently focused text field.

**Core value proposition:** Talk freely without worrying about precision or coherence — Yap transcribes and intelligently restructures your speech into clean, organized text while preserving all the detail and context you provided. Speaking is faster than typing — Yap makes sure that speed advantage isn't lost to compression or summarization.

---

## Tech Stack

| Component | Technology |
|---|---|
| App framework | **Flutter** (single codebase, native Windows + macOS) |
| Language | **Dart** |
| System tray | `tray_manager` or `system_tray` package |
| Global hotkey | `hotkey_manager` + platform channels for low-level double-tap detection |
| Overlay window | `screen_retriever` + `window_manager` (always-on-top, frameless panel) |
| Audio capture | Platform channels → native audio APIs (`AVAudioEngine` on macOS, `NAudio`/WASAPI on Windows) |
| Transcription | **AssemblyAI** real-time streaming API (WebSocket via `web_socket_channel`) |
| LLM | **Claude API** (Anthropic SDK via direct HTTP, `dio` or `http` package) |
| Local database | **Drift** (SQLite wrapper for Dart) |
| Paste simulation | Platform channels → `CGEvent` on macOS, `SendInput` on Windows |
| Clipboard | `clipboard` package + platform channels for save/restore |
| Audio playback | `audioplayers` (for sound cues) |
| State management | **Riverpod** |
| Installer | **MSIX** (Windows), **DMG** (macOS) |

### Platform Channels (native code required)

Some features cannot be done in pure Dart and require thin native layers:

| Feature | macOS (Swift) | Windows (C++) |
|---|---|---|
| Double-tap hotkey detection | `CGEventTap` | `SetWindowsHookEx` |
| Audio capture | `AVAudioEngine` → PCM stream | WASAPI / `NAudio` → PCM stream |
| Paste simulation | `CGEvent` Cmd+V | `SendInput` Ctrl+V |
| Accessibility permissions | `AXIsProcessTrusted()` prompt | N/A |

---

## User Flow

### Primary Flow

```
1. User double-taps Left Cmd (macOS) / Left Alt (Windows)
2. Overlay appears at top-center of screen with soundwave animation
   → Sound cue plays (recording started)
3. User speaks — streaming transcript appears in real-time
4. User double-taps trigger again to stop recording
   → Sound cue plays (recording stopped)
5. Overlay shows final transcript with options:
   ┌─────────────────────────────────────────┐
   │ [Transcript text here...]               │
   │                                         │
   │ Enter: Paste raw  │  1-4: Prompt profile│
   │ 1 · Structured prompt                   │
   │ 2 · Clean transcript                    │
   │ 3 · Fix grammar                         │
   │ 4 · (user-defined)                      │
   │                              Esc: Cancel│
   └─────────────────────────────────────────┘
6a. User presses Enter → raw transcript is pasted
6b. User presses 1-4 → LLM processes with selected profile
   → Spinner/loading indicator shown
   → Streaming LLM output replaces transcript in overlay
7. User presses Enter to paste / Esc to cancel
8. Result is pasted into the focused text field
   → If no text field detected: copied to clipboard with notification
```

### Paste Mechanism

1. Save current clipboard contents
2. Copy result text to clipboard
3. Simulate `Cmd+V` (macOS) / `Ctrl+V` (Windows) via platform channel
4. Restore previous clipboard contents

This requires accessibility permissions on macOS and `SendInput` on Windows.

---

## Activation

| | macOS | Windows |
|---|---|---|
| **Trigger** | Double-tap Left Command | Double-tap Left Alt |
| **Detection** | `CGEventTap` via Swift platform channel | `SetWindowsHookEx` via C++ platform channel |
| **Double-tap window** | ~400ms between taps (configurable) |

The trigger is a toggle:
- First double-tap: start recording
- Second double-tap: stop recording

---

## Overlay UI

### Positioning & Layout
- **Position:** Top-center of screen, grows downward
- **Rationale:** Avoids blocking text fields which are typically lower on screen
- **Size:** Larger panel — full scrollable transcript visible, not just a minimal bubble
- **Always-on-top:** Yes, while active
- **Style:** Frameless, rounded, semi-transparent background, follows OS light/dark mode

### States

#### 1. Recording
- Soundwave/waveform animation showing audio is being captured
- Streaming transcript text appearing in real-time
- Elapsed time indicator
- Visual recording indicator (red dot or similar)

#### 2. Transcript Complete (awaiting user action)
- Full transcript displayed (scrollable)
- Prompt profile options listed with number keys
- `Enter` = paste raw, `Esc` = cancel

#### 3. LLM Processing
- Spinner or loading animation
- Streaming LLM output replacing/appearing below the transcript
- Profile name shown (e.g. "Processing with: Structured prompt")

#### 4. Ready to Paste
- Final processed text shown
- `Enter` = paste, `Esc` = cancel

### Sound Cues
- **Recording start:** Short, subtle sound (think macOS dictation beep)
- **Recording stop:** Distinct end sound
- Ship default sounds, optionally allow customization later

---

## Prompt Profiles

### Philosophy

The whole point of speaking instead of typing is that you can provide far more detail and context in less time. **Prompt profiles must preserve that richness.** They organize and clean up — they never summarize, condense, or drop specifics. A 2-minute voice dump should produce a well-structured output with the same depth of information, not a 3-bullet summary.

### Overview
Up to **4** prompt profiles. Users select via number keys `1-4` after transcription completes.

### Default Profiles

#### 1 — Structured Prompt
```
You are a prompt engineer. Take the following transcribed speech and convert it into
a well-structured prompt for an AI assistant.

CRITICAL RULES:
- PRESERVE ALL DETAIL AND CONTEXT the speaker provided. The speaker chose to say
  these things because they matter. Do not summarize, condense, or drop specifics.
- Organize the thoughts logically — group related ideas, add structure (headers,
  bullets, numbered steps) — but do NOT reduce the content
- If the speaker gave examples, keep them. If they described constraints, keep them.
  If they gave background context, keep it — context is what makes prompts effective.
- Remove only: filler words (um, uh, like), false starts, self-corrections
  (use the final version of contradicted statements)
- Remove conversational artifacts ("so basically", "you know what I mean")
- The output should read like a well-organized written prompt that happens to contain
  the same depth of information as the original speech
- Output only the formatted prompt, no meta-commentary
```

#### 2 — Clean Transcript
```
You are a transcript editor. Take the following transcribed speech and clean it up
while preserving the full content and the speaker's voice.

CRITICAL RULES:
- Keep ALL the detail, context, and reasoning the speaker provided
- Fix grammar, punctuation, and sentence structure
- Remove filler words, false starts, and repetition
- Resolve self-corrections (keep only final intent)
- Organize into paragraphs by topic — but do not summarize or compress
- Preserve the speaker's tone and word choices where possible
- Output only the cleaned text, no commentary
```

#### 3 — Fix Grammar
```
You are a copy editor. Fix grammar, punctuation, and spelling only.
Minimal changes. Keep the speaker's exact words and structure.
Do not restructure or summarize. Output only the corrected text.
```

#### 4 — (Empty slot for user)

### Profile Customization
In settings, users can:
- Edit the system prompt for any profile (including defaults)
- Rename profiles
- The number shown in the overlay matches the profile slot (1-4)

---

## Recording

| Parameter | Value |
|---|---|
| Max duration | 30 minutes |
| Audio format | PCM/WAV (required by AssemblyAI real-time) |
| Sample rate | 16kHz (AssemblyAI recommended) |
| Channels | Mono |

### Long Recording Handling
If the transcript exceeds the Claude API input context limit:
1. Split the transcript into overlapping chunks (overlap ~200 words for context continuity)
2. Process each chunk with the selected prompt profile
3. Run a final combine pass: send all processed chunks to Claude with instructions to merge into one coherent output
4. Present the combined result to the user

---

## Transcription (AssemblyAI)

- Use **AssemblyAI Real-Time Streaming** API
- Connect via WebSocket when recording starts
- Stream audio chunks as they are captured
- Display partial/final transcripts in the overlay in real-time
- Close WebSocket when recording stops
- Combine all final transcript segments into the complete text

---

## LLM Processing (Claude API)

- **Model:** `claude-sonnet-4-20250514` (latest Sonnet, configurable)
- **Streaming:** Yes — stream the response so users see output appearing
- **System prompt:** The selected profile's prompt
- **User message:** The full transcript
- **Max output tokens:** Proportional to input length, with reasonable cap

---

## Settings

Accessible from system tray menu → "Settings" or via gear icon in overlay.

### API Keys
- AssemblyAI API key (required)
- Anthropic API key (required)
- Validation on save (test API connectivity)

### Prompt Profiles
- List of 4 profiles
- Each profile: name (displayed in overlay) + system prompt (textarea)
- Reset to default button per profile

### General
- **Auto-start on boot:** Toggle (default: off)
- **Double-tap speed:** Slider, 200ms–600ms (default: 400ms)
- **Claude model:** Dropdown (Haiku / Sonnet / Opus)
- **Sound cues:** Toggle on/off

### History
- Toggle history recording on/off
- Clear history button
- Storage location info

---

## History

- Stored in local **SQLite** database (via Drift)
- Location: OS-appropriate app data directory

### Schema

```sql
CREATE TABLE history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_transcript TEXT NOT NULL,
    profile_name TEXT,            -- NULL if raw paste (no LLM)
    profile_prompt TEXT,          -- snapshot of prompt used
    processed_text TEXT,          -- NULL if raw paste
    pasted_text TEXT NOT NULL,    -- what was actually pasted
    duration_seconds REAL         -- recording duration
);
```

### History View
- Accessible from system tray menu → "History"
- Scrollable list, newest first
- Each entry shows: timestamp, profile used (or "Raw"), preview of pasted text
- Click to expand: full transcript, processed text, option to copy

---

## System Tray

### Menu Items
- **Yap** (title, disabled)
- ---
- Start/Stop Recording (mirrors the keyboard shortcut)
- ---
- History
- Settings
- ---
- About
- Quit

### Tray Icon
- Default state: microphone icon (subtle, monochrome to match OS conventions)
- Recording state: microphone with red indicator or animation

---

## Platform-Specific Considerations

### macOS
- **Accessibility permission** required for simulating paste keystrokes
- **Microphone permission** required for audio capture
- App should prompt for permissions on first launch with clear explanation
- Menu bar icon (top-right area) — standard `NSStatusItem`
- Code signing required for distribution
- Native Swift platform channel for: `CGEventTap`, `AVAudioEngine`, `CGEvent` paste

### Windows
- **No special permissions** for `SendInput` (keystroke simulation)
- Microphone access through Windows privacy settings
- System tray icon (bottom-right notification area)
- May need to handle "Focus Assist" / DND modes
- Native C++ platform channel for: `SetWindowsHookEx`, WASAPI audio, `SendInput` paste

---

## Error Handling

| Scenario | Behavior |
|---|---|
| No internet | Show error in overlay: "No connection — check network" |
| AssemblyAI API error | Show error, offer to retry or cancel |
| Claude API error | Show error, allow pasting raw transcript instead |
| Invalid API keys | Show error in overlay with link to settings |
| No microphone permission | Prompt user to grant permission |
| Recording exceeds 30 min | Auto-stop with notification |
| Paste fails (no text field) | Copy to clipboard, show notification |

---

## v1 Requirements

- **Localization:** English only for v1
- **Theming:** Follow OS light/dark mode automatically (no custom theme)

---

## Out of Scope (v1)

- Auto-updates (ship manually, add later)
- Offline transcription
- Mobile platforms (iOS/Android)
- Multi-language transcription (support later via AssemblyAI language param)
- Custom hotkey configuration (use fixed double-tap for v1)
- Audio playback from history
- Plugin/extension system
- Team/shared prompt profiles
- End-to-end encryption of history
- Custom theming beyond OS light/dark

---

## Success Metrics

- **Latency:** From stop-recording to paste-ready should be under 3 seconds for short inputs (<30s of speech)
- **Accuracy:** Transcription should match AssemblyAI's stated accuracy benchmarks
- **Reliability:** Paste should succeed >95% of the time in common apps (browsers, editors, messaging apps)
- **Detail preservation:** Processed output should contain the same substantive information as the raw transcript — structured better, not shorter

---

## Project Structure

```
yap/
├── PRD.md
├── lib/                      # Dart application code
│   ├── main.dart
│   ├── app.dart
│   ├── features/
│   │   ├── overlay/          # Overlay window UI & state
│   │   ├── recording/        # Audio capture & transcription
│   │   ├── processing/       # LLM prompt processing
│   │   ├── settings/         # Settings UI & persistence
│   │   ├── history/          # History UI & database
│   │   └── tray/             # System tray integration
│   ├── services/
│   │   ├── assemblyai/       # AssemblyAI WebSocket client
│   │   ├── claude/           # Claude API client
│   │   ├── audio/            # Audio capture service (wraps platform channel)
│   │   ├── hotkey/           # Global hotkey service (wraps platform channel)
│   │   ├── paste/            # Clipboard save/restore + paste simulation
│   │   └── database/         # Drift database definitions
│   └── shared/
│       ├── prompts/          # Default prompt profile text
│       └── theme/            # OS-aware theming
├── macos/                    # macOS runner + Swift platform channels
│   └── Runner/
│       └── PlatformChannels/ # CGEventTap, AVAudioEngine, CGEvent paste
├── windows/                  # Windows runner + C++ platform channels
│   └── runner/
│       └── platform_channels/ # SetWindowsHookEx, WASAPI, SendInput
├── assets/
│   └── sounds/               # Start/stop sound cues
├── test/
└── pubspec.yaml
```

---

## Resolved Decisions

1. **Framework:** Flutter (cross-platform, single codebase for Windows + macOS)
2. **State management:** Riverpod
3. **Database:** Drift (SQLite)
4. **Auto-updates:** Deferred to post-v1
5. **Localization:** English only for v1
6. **Theming:** Follow OS light/dark mode, no custom theme
7. **Prompt philosophy:** Organize and structure, never condense — preserve all detail and context from speech
