# Agent 2 — Audio & Transcription Pipeline

## Your Role

You are building the real-time audio-to-transcript pipeline. You take raw PCM audio from the `AudioService` (provided by Agent 1), stream it to AssemblyAI via WebSocket, and expose a clean Dart service that emits partial and final transcript segments in real-time.

---

## What You Own

```
lib/
├── services/
│   └── assemblyai/
│       ├── assemblyai_service.dart          # Main service interface & implementation
│       ├── assemblyai_models.dart           # Data models for API messages
│       └── assemblyai_config.dart           # API configuration
├── features/
│   └── recording/
│       ├── recording_service.dart           # Orchestrates audio + transcription
│       ├── recording_state.dart             # State model for the recording session
│       └── recording_providers.dart         # Riverpod providers
└── test/
    ├── services/
    │   └── assemblyai_service_test.dart
    └── features/
        └── recording/
            └── recording_service_test.dart
```

---

## Deliverable 1: AssemblyAI Real-Time Service

### Interface & Implementation (`assemblyai_service.dart`)

```dart
enum TranscriptType { partial, final_ }

class TranscriptSegment {
  final String text;
  final TranscriptType type;
  final double audioStart;  // seconds
  final double audioEnd;    // seconds
  final DateTime receivedAt;
}

abstract class AssemblyAIService {
  /// Stream of transcript segments (both partial and final).
  /// Partial segments update in real-time as the user speaks.
  /// Final segments are committed — they won't change.
  Stream<TranscriptSegment> get transcriptStream;

  /// Connect to AssemblyAI and begin streaming audio.
  /// [audioStream] is the raw PCM stream from AudioService.
  /// [apiKey] is the AssemblyAI API key.
  Future<void> startSession({
    required Stream<Uint8List> audioStream,
    required String apiKey,
  });

  /// Gracefully close the WebSocket session.
  /// Returns the final combined transcript (all final segments joined).
  Future<String> endSession();

  /// Whether a session is currently active.
  bool get isActive;
}
```

### AssemblyAI Real-Time Protocol

Reference: AssemblyAI Real-Time Streaming API

**WebSocket URL:** `wss://api.assemblyai.com/v2/realtime/ws`

**Query parameters:**
- `sample_rate=16000`
- `token=<api_key>` (or use auth header)

**Sending audio:**
- Send raw PCM audio as base64-encoded strings in JSON: `{ "audio_data": "<base64>" }`
- Send chunks frequently (~100ms intervals, matching the AudioService chunk size)

**Receiving transcripts:**
- Messages arrive as JSON with this shape:
```json
{
  "message_type": "PartialTranscript" | "FinalTranscript",
  "text": "the transcribed text",
  "audio_start": 0,
  "audio_end": 1440,
  "words": [{ "text": "the", "start": 0, "end": 200, "confidence": 0.99 }]
}
```
- `PartialTranscript`: interim result, will be replaced by the next partial or a final
- `FinalTranscript`: committed result, won't change

**Session termination:**
- Send `{ "terminate_session": true }` to gracefully end
- Wait for the `SessionTerminated` message before closing the WebSocket

### Implementation Details

- Use `web_socket_channel` package for the WebSocket connection
- Base64-encode PCM chunks before sending
- Parse incoming JSON messages and emit `TranscriptSegment` objects
- Handle reconnection: if WebSocket drops unexpectedly, emit an error event (don't auto-reconnect — let the recording service decide)
- Handle the `SessionTerminated` message to know when it's safe to close

### Models (`assemblyai_models.dart`)

```dart
/// Raw JSON message from AssemblyAI
class AssemblyAIMessage {
  final String messageType;  // PartialTranscript, FinalTranscript, SessionTerminated, etc.
  final String? text;
  final int? audioStart;
  final int? audioEnd;
  final List<WordInfo>? words;

  factory AssemblyAIMessage.fromJson(Map<String, dynamic> json);
}

class WordInfo {
  final String text;
  final int start;
  final int end;
  final double confidence;
}
```

### Config (`assemblyai_config.dart`)

```dart
class AssemblyAIConfig {
  static const String wsUrl = 'wss://api.assemblyai.com/v2/realtime/ws';
  static const int sampleRate = 16000;
  static const Duration sendInterval = Duration(milliseconds: 100);
}
```

---

## Deliverable 2: Recording Service

The recording service orchestrates the full recording lifecycle: hotkey trigger → audio capture → transcription → final transcript.

### State Model (`recording_state.dart`)

```dart
enum RecordingStatus {
  idle,         // Not recording
  recording,    // Actively capturing audio + transcribing
  stopping,     // Double-tap received, waiting for final transcript
  complete,     // Transcript ready for user action
  error,        // Something went wrong
}

class RecordingState {
  final RecordingStatus status;
  final String currentTranscript;      // Latest full text (partials + finals combined)
  final String finalTranscript;        // Only committed final segments
  final Duration elapsed;              // How long the user has been recording
  final String? errorMessage;
  final DateTime? startedAt;
}
```

### Service (`recording_service.dart`)

```dart
abstract class RecordingService {
  /// Current state of the recording session.
  RecordingState get state;

  /// Stream of state changes.
  Stream<RecordingState> get stateStream;

  /// Start a new recording session.
  /// - Starts audio capture via AudioService
  /// - Connects to AssemblyAI
  /// - Begins streaming audio and receiving transcripts
  Future<void> startRecording();

  /// Stop the current recording session.
  /// - Stops audio capture
  /// - Sends terminate_session to AssemblyAI
  /// - Waits for final transcript
  /// - Transitions to RecordingStatus.complete
  Future<void> stopRecording();

  /// Cancel and discard the current session.
  Future<void> cancelRecording();
}
```

### How It Works

1. `startRecording()`:
   - Get API key from settings (via a provider — Agent 3 owns settings persistence)
   - Call `audioService.startCapture()`
   - Call `assemblyAIService.startSession(audioStream: audioService.audioStream, apiKey: key)`
   - Start an elapsed-time timer
   - Listen to `assemblyAIService.transcriptStream` and build up the current transcript
   - For display: combine all final segments + the latest partial segment

2. Building the display transcript:
   - Maintain a list of final segment texts
   - When a new `FinalTranscript` arrives, append its text
   - When a `PartialTranscript` arrives, show it after the finals (it will be replaced)
   - `currentTranscript` = finals joined + " " + latest partial
   - `finalTranscript` = finals joined (used for LLM processing)

3. `stopRecording()`:
   - Call `audioService.stopCapture()`
   - Call `assemblyAIService.endSession()` — this returns the final combined text
   - Set `status = complete`, `finalTranscript` = the combined text

4. Max duration enforcement:
   - If elapsed time reaches 30 minutes, auto-call `stopRecording()`
   - Emit a state update so the UI can show a notification

### Riverpod Providers (`recording_providers.dart`)

```dart
/// Provides the RecordingService singleton
@riverpod
RecordingService recordingService(RecordingServiceRef ref) {
  final audioService = ref.watch(audioServiceProvider);
  final assemblyAIService = ref.watch(assemblyAIServiceProvider);
  final apiKey = ref.watch(assemblyAIApiKeyProvider);
  return RecordingServiceImpl(audioService, assemblyAIService, apiKey);
}

/// Provides the current recording state (rebuilds on change)
@riverpod
Stream<RecordingState> recordingState(RecordingStateRef ref) {
  return ref.watch(recordingServiceProvider).stateStream;
}
```

---

## Dependencies on Other Agents

### From Agent 1 (Platform Layer):
- `AudioService` interface — you call `startCapture()`, `stopCapture()`, and listen to `audioStream`
- `AudioService` is provided as a Riverpod provider: `audioServiceProvider`
- Audio chunks are `Uint8List`, PCM 16-bit signed LE, 16kHz, mono, ~100ms per chunk

### From Agent 3 (LLM & Data):
- `assemblyAIApiKeyProvider` — a Riverpod provider that gives you the stored API key as `String?`
- If the key is null/empty, `startRecording()` should throw with a clear error message

---

## What Other Agents Depend On From You

### Agent 4 (UI) depends on:
- `recordingServiceProvider` — to call `startRecording()` / `stopRecording()` / `cancelRecording()`
- `recordingStateProvider` — to display transcript, elapsed time, status in the overlay
- `RecordingState.finalTranscript` — the completed transcript that gets sent to LLM processing
- `RecordingState.status` — to know which overlay state to show

---

## Error Handling

| Scenario | Behavior |
|---|---|
| No API key configured | Throw `NoApiKeyException` — UI will show settings prompt |
| WebSocket connection fails | Set `status = error`, `errorMessage` = connection error details |
| WebSocket drops mid-session | Set `status = error`, preserve any transcript received so far in `finalTranscript` |
| No microphone permission | Throw `MicrophonePermissionException` — UI will prompt for permission |
| Audio capture fails | Set `status = error` with details |
| 30 min limit reached | Auto-stop, set `status = complete` normally |

---

## Testing

- **AssemblyAI service tests:** Mock the WebSocket. Send fake partial/final transcript messages. Verify the stream emits correct `TranscriptSegment` objects. Test session termination flow.
- **Recording service tests:** Mock both `AudioService` and `AssemblyAIService`. Test the full lifecycle: start → receive transcripts → stop → final transcript. Test error scenarios. Test 30-minute auto-stop.
- **Transcript building tests:** Verify that partials are correctly replaced by finals, and that the display transcript is assembled correctly.

---

## Key Constraints

- Audio MUST be sent as base64-encoded PCM in JSON, not raw binary
- Partial transcripts are ephemeral — only final transcripts should be kept for LLM processing
- The WebSocket must be gracefully terminated (send `terminate_session`, wait for `SessionTerminated`) — don't just close it, or you may lose the last few seconds of transcript
- Keep the transcript building logic simple: list of final texts + latest partial. Don't try to be clever with word-level merging.
