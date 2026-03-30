# Services

## Service Layer Overview

Services are organized in `lib/services/` (platform services) and `lib/features/*/` (feature services). All are provided via Riverpod and follow the abstract-interface + impl pattern.

## Platform Services (`lib/services/`)

### HotkeyService
- **Interface:** `hotkey/hotkey_service.dart`
- **Impl:** `hotkey/hotkey_service_impl.dart`
- **Provider:** `providers.dart` → `hotkeyServiceProvider`
- **Exposes:** `Stream<void> onDoubleTap` — fires when double-tap detected
- **Lifecycle:** `start(triggerKey?)` → `stop()` (via `ref.onDispose`)

### AudioService
- **Interface:** `audio/audio_service.dart`
- **Impl:** `audio/audio_service_impl.dart`
- **Provider:** `providers.dart` → `audioServiceProvider`
- **Exposes:** `Stream<Uint8List> audioStream`, `Stream<double> levelStream`
- **Lifecycle:** `startCapture(deviceId?)` → `stopCapture()`

### PasteService
- **Interface:** `paste/paste_service.dart`
- **Impl:** `paste/paste_service_impl.dart`
- **Provider:** `providers.dart` → `pasteServiceProvider`
- **Method:** `pasteText(String text)` — clipboard + keystroke simulation

### AssemblyAIService (`assemblyai/`)
- **WebSocket streaming** transcription
- **Flow:** Request temp token → connect WebSocket → stream audio chunks → receive transcript segments
- **Segment types:** Partial (in-progress) and Final (committed)
- **Config:** `assemblyai_config.dart` — endpoints, audio format, speech model

### ClaudeService (`claude/`)
- **HTTP + SSE streaming** to Claude API
- **Flow:** Build messages request → POST with `stream: true` → parse SSE chunks → yield text deltas
- **Config:** `claude_config.dart` — API URL, version, model mapping
- **Models:** `claude_models.dart` — request/response types, typed exceptions

## Feature Services (`lib/features/`)

### RecordingService (`recording/`)
- **Orchestrates:** AudioService + AssemblyAIService
- **State:** `RecordingState` (idle, recording, stopping, complete, error)
- **Emits:** State stream with real-time transcript (`currentTranscript` = finals + latest partial)
- **Max duration:** 30 minutes (auto-stop)
- **Methods:** `startRecording()`, `stopRecording()`, `cancelRecording()`

### ProcessingService (`processing/`)
- **Orchestrates:** ClaudeService + PromptProfileDao
- **State:** `ProcessingState` (idle, processing, complete, error)
- **Emits:** State stream with streaming LLM output
- **Methods:** `processWithProfile(transcript, slot)`, `cancel()`
- **Token logic:** Adjusts `max_tokens` based on transcript word count

### OverlayController (`overlay/overlay_controller.dart`)
- **Central orchestrator** — manages the full recording → processing → paste lifecycle
- **Subscribes to:** HotkeyService (double-tap), RecordingService (state), ProcessingService (state)
- **Manages:** OverlayWindow (show/hide/position), keyboard input (Enter/Esc/1-4)
- **State:** `YapOverlayState` with phases: hidden, recording, transcriptComplete, processing, readyToPaste, copied, error

### SettingsService (`settings/`)
- **Key-value store** backed by SettingsDao
- **Keys:** API keys, model, threshold, sound cues, history, autostart, trigger key, microphone
- **Methods:** Typed getters/setters for each setting

### HistoryService (`history/`)
- **CRUD** for transcription history entries
- **Watch:** Reactive list updates for UI via Drift watch queries

### TrayService (`tray/`)
- **System tray icon** + context menu (Start/Stop, Settings, History, Quit)
- **Icon swapping:** Idle vs recording states
- **Callbacks:** `onToggleRecording`, `onOpenSettings`, `onOpenHistory`

## Data Flow

```
HotkeyService.onDoubleTap
    │
    ▼
OverlayController._startRecording()
    │
    ├── RecordingService.startRecording()
    │       ├── AudioService.startCapture()
    │       ├── AssemblyAIService.startSession()
    │       └── Stream: transcript updates
    │
    ▼
OverlayController (hotkey again) → RecordingService.stopRecording()
    │
    ▼
User presses 1-4:
    ProcessingService.processWithProfile()
        └── ClaudeService.processTranscript() → SSE stream
    │
    ▼
User presses Enter:
    PasteService.pasteText()
    HistoryService.saveEntry()
    OverlayWindow.hide()
```
