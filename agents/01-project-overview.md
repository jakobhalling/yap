# Project Overview

## What Is Yap?

Yap is a cross-platform desktop tray application that turns voice into polished text. It lives in the system tray, activates via a configurable global hotkey (double-tap a modifier key), captures audio with real-time streaming transcription, optionally processes the transcript through an LLM, and pastes the result into whatever app the user was working in.

## Core Idea

Speaking is faster than typing, but raw speech is messy. Yap bridges that gap: speak naturally, get clean text. The LLM processing step is optional — users can paste raw transcripts or run them through customizable prompt profiles that restructure, clean up, or transform the text.

## Key Surfaces

1. **System tray icon** — persistent presence, context menu for settings/history/quit
2. **Overlay window** — floating, borderless, top-center of screen; shows recording state, transcript, and processing output
3. **Settings window** — API keys, model selection, hotkey config, prompt profiles, history management
4. **History window** — past transcriptions with search/detail view
5. **Setup wizard** — first-boot flow for API key entry

## User Flow

```
1. Double-tap hotkey → overlay appears, recording starts
2. Speak → real-time transcript displayed
3. Double-tap hotkey again → recording stops
4. Choose action:
   • Enter → paste raw transcript
   • 1-4 → process with prompt profile, then Enter to paste
   • Esc → cancel
5. Text pasted into focused app → overlay hides
```

## What It Does NOT Do

- No always-listening mode — explicit activation only
- No cloud accounts or user auth
- No editing of transcripts within the overlay (paste-and-go)
- No Linux support (macOS + Windows only)

## Where to Find Details

- Full requirements: `PRD.md` in repo root
- Project structure: `agents/02-project-structure.md`
- Tech stack: `agents/03-tech-stack.md`
- Platform channels: `agents/04-platform-channels.md`
- Services: `agents/05-services.md`
- Database: `agents/06-database.md`
