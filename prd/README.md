# Yap — Agent Work Breakdown

## Overview

The Yap PRD is split into 4 parallel workstreams. Each agent works independently against defined interfaces, then integration happens at the end.

## Agents

| Agent | Scope | Key Deliverables |
|---|---|---|
| **1 — Platform & Scaffold** | App shell, native platform channels, theme | `pubspec.yaml`, `main.dart`, `HotkeyService`, `AudioService`, `PasteService`, sound assets |
| **2 — Audio & Transcription** | AssemblyAI integration, recording lifecycle | `AssemblyAIService`, `RecordingService`, `RecordingState` |
| **3 — LLM & Data** | Claude API, database, settings, history, prompts | `ClaudeService`, `ProcessingService`, Drift DB, `SettingsService`, `HistoryService`, default prompts |
| **4 — UI** | Overlay, settings screen, history screen, system tray, keyboard handling | All widgets, `OverlayController`, `TrayService`, keyboard flow |

## Dependency Graph

```
Agent 1 (Platform)
  │
  ├──► Agent 2 (Audio & Transcription)
  │       uses: AudioService
  │
  ├──► Agent 3 (LLM & Data)
  │       uses: Riverpod scope, pubspec deps
  │
  └──► Agent 4 (UI)
          uses: HotkeyService, PasteService, AudioService permissions, theme, window_manager

Agent 3 (LLM & Data)
  │
  ├──► Agent 2 reads: assemblyAIApiKeyProvider
  │
  └──► Agent 4 reads: ProcessingService, SettingsService, HistoryService, PromptProfileDao, ClaudeService

Agent 2 (Audio & Transcription)
  │
  └──► Agent 4 reads: RecordingService, RecordingState
```

## Integration Order

1. **Agent 1 finishes first** — provides the scaffold everyone else drops code into
2. **Agents 2 & 3 can work fully in parallel** — they don't depend on each other (Agent 2 only needs a provider name from Agent 3, documented in the PRD)
3. **Agent 4 can start immediately** on widget code (mocking all services), but final wiring needs Agents 1-3

## Interface Contracts

Each agent PRD documents:
- The **abstract Dart interfaces** they must implement
- The **Riverpod provider names** they expose
- The **platform channel contracts** (method names, payloads, directions)
- What they **depend on** from other agents
- What **other agents depend on** from them

Agents should code against the interfaces, not implementations. This allows parallel work.
