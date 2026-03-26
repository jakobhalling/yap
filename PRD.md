# Yap — Product Requirements Document

## Overview

Yap is a cross-platform (macOS & Windows) system tray application that enables voice-driven text input into any application. The user activates Yap with a global shortcut, speaks, sees a real-time streaming transcript, optionally processes it through an LLM with customizable prompt profiles, and pastes the result into the currently focused text field.

**Core value proposition:** Talk freely without worrying about precision or coherence — Yap transcribes and intelligently rewrites your speech into clean, structured text.

---

## Tech Stack

| Component | Technology |
|---|---|
| App framework | **Tauri v2** (Rust backend + web frontend) |
| Frontend | **Svelte** + TypeScript |
| Transcription | **AssemblyAI** real-time streaming API |
| LLM | **Claude API** (Sonnet model, via Anthropic SDK) |
| Local database | **SQLite** (via `rusqlite` or Tauri SQL plugin) |
| Audio capture | Native OS audio APIs via Rust (`cpal` crate) |

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
   │ 1 · Clear & concise                     │
   │ 2 · Agent prompt                        │
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
3. Simulate `Cmd+V` (macOS) / `Ctrl+V` (Windows)
4. Restore previous clipboard contents

This requires accessibility permissions on macOS and appropriate APIs on Windows (`SendInput`).

---

## Activation

| | macOS | Windows |
|---|---|---|
| **Trigger** | Double-tap Left Command | Double-tap Left Alt |
| **Detection** | Monitor key events globally via `CGEventTap` or similar | Low-level keyboard hook (`SetWindowsHookEx`) |
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
- Profile name shown (e.g. "Processing with: Clear & concise")

#### 4. Ready to Paste
- Final processed text shown
- `Enter` = paste, `Esc` = cancel

### Sound Cues
- **Recording start:** Short, subtle sound (think macOS dictation beep)
- **Recording stop:** Distinct end sound
- Ship default sounds, optionally allow customization later

---

## Prompt Profiles

### Overview
Up to **4** prompt profiles. Users select via number keys `1-4` after transcription completes.

### Default Profiles

#### 1 — Clear & Concise
```
You are a text editor. Take the following transcribed speech and produce a clear,
concise version. Key rules:
- If the speaker contradicts themselves (e.g. "do A" then later "no, don't do A"),
  only include the final intent — omit the retracted points entirely
- Extract and organize the key points logically, not chronologically
- Remove filler, repetition, and false starts
- Preserve the speaker's voice and intent
- Output only the cleaned text, no commentary
```

#### 2 — Agent Prompt
```
You are a prompt engineer. Take the following transcribed speech and convert it into
a well-structured prompt/instruction for an AI agent. Key rules:
- Extract the core task and requirements
- Structure as clear, actionable instructions
- Remove conversational artifacts and filler
- Resolve any contradictions (use the latest stated intent)
- Output only the formatted prompt, no commentary
```

#### 3 — Fix Grammar
```
You are a copy editor. Take the following transcribed speech and fix grammar,
punctuation, and spelling while preserving the original meaning and tone. Key rules:
- Minimal changes — only fix actual errors
- Keep the speaker's word choices and style
- Do not restructure or summarize
- Output only the corrected text, no commentary
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

- Stored in local **SQLite** database
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

### Windows
- **No special permissions** for `SendInput` (keystroke simulation)
- Microphone access through Windows privacy settings
- System tray icon (bottom-right notification area)
- May need to handle "Focus Assist" / DND modes

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

## Additional v1 Requirements

- **Auto-updates:** Use Tauri's built-in updater for seamless updates
- **Localization:** English only for v1
- **Theming:** Follow OS light/dark mode automatically (no custom theme)

---

## Out of Scope (v1)

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

---

## Resolved Decisions

1. **Frontend framework:** Svelte (lightweight, excellent Tauri ecosystem support)
2. **Auto-updates:** Yes, via Tauri built-in updater
3. **Localization:** English only for v1
4. **Theming:** Follow OS light/dark mode, no custom theme
