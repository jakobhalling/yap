# Agent 1 — Platform Layer & App Scaffold

## Your Role

You are building the Flutter app scaffold and all native platform channel code. You provide the foundation that every other agent builds on. Your deliverables are **abstract Dart interfaces** with **native implementations** behind platform channels, plus the runnable app shell.

---

## What You Own

```
yap/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── app.dart                           # MaterialApp, routing, Riverpod root
│   ├── services/
│   │   ├── hotkey/
│   │   │   ├── hotkey_service.dart         # Abstract interface
│   │   │   └── hotkey_service_impl.dart    # Platform channel wrapper
│   │   ├── audio/
│   │   │   ├── audio_service.dart          # Abstract interface
│   │   │   └── audio_service_impl.dart     # Platform channel wrapper
│   │   └── paste/
│   │       ├── paste_service.dart          # Abstract interface
│   │       └── paste_service_impl.dart     # Platform channel wrapper
│   └── shared/
│       └── theme/
│           └── app_theme.dart              # OS-aware light/dark theme
├── macos/
│   └── Runner/
│       ├── AppDelegate.swift               # Register platform channels
│       └── PlatformChannels/
│           ├── HotkeyChannel.swift         # CGEventTap double-tap detection
│           ├── AudioCaptureChannel.swift    # AVAudioEngine → PCM stream
│           └── PasteChannel.swift          # CGEvent Cmd+V simulation
├── windows/
│   └── runner/
│       ├── main.cpp                        # Register platform channels
│       └── platform_channels/
│           ├── hotkey_channel.cpp           # SetWindowsHookEx double-tap detection
│           ├── audio_capture_channel.cpp    # WASAPI → PCM stream
│           └── paste_channel.cpp            # SendInput Ctrl+V simulation
├── assets/
│   └── sounds/
│       ├── record_start.wav
│       └── record_stop.wav
├── pubspec.yaml
└── test/
    └── services/
        ├── hotkey_service_test.dart
        ├── audio_service_test.dart
        └── paste_service_test.dart
```

---

## Deliverable 1: Flutter App Scaffold

### `pubspec.yaml`
Set up the project with all dependencies the team needs:

```yaml
name: yap
description: Voice-driven text input for any application

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  web_socket_channel: ^2.4.0
  dio: ^5.4.0
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.8.0
  window_manager: ^0.3.7
  screen_retriever: ^0.1.9
  system_tray: ^2.0.3
  audioplayers: ^5.2.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  drift_dev: ^2.14.0
  riverpod_generator: ^2.3.0
  flutter_lints: ^3.0.0
```

### `main.dart`
- Initialize `WidgetsFlutterBinding`
- Initialize `windowManager` (frameless, hidden on launch — tray-only app)
- Wrap app in `ProviderScope`
- Launch `App`

### `app.dart`
- `MaterialApp` with OS-aware theming (light/dark via `MediaQuery.platformBrightness`)
- No visible main window — app lives in system tray
- Overlay is a separate window managed by `window_manager`

### `app_theme.dart`
- Light and dark `ThemeData` that follow OS settings
- Semi-transparent overlay background color
- Consistent text styles for transcript display

---

## Deliverable 2: Hotkey Service

### Dart Interface (`hotkey_service.dart`)

```dart
abstract class HotkeyService {
  /// Stream that emits an event each time the user double-taps the trigger key.
  /// The trigger is Left Cmd on macOS, Left Alt on Windows.
  Stream<void> get onDoubleTap;

  /// Start listening for the global hotkey. Call once at app startup.
  Future<void> start();

  /// Stop listening. Call on app shutdown.
  Future<void> stop();

  /// Update the double-tap detection window (in milliseconds).
  /// Default: 400ms. Range: 200–600ms.
  Future<void> setDoubleTapThreshold(int milliseconds);
}
```

### Platform Channel Contract

**Channel name:** `com.yap.hotkey`

| Method | Direction | Payload | Description |
|---|---|---|---|
| `start` | Dart → Native | `{ "threshold": 400 }` | Begin global key monitoring |
| `stop` | Dart → Native | — | Stop monitoring |
| `setThreshold` | Dart → Native | `{ "threshold": int }` | Update double-tap window |
| `onDoubleTap` | Native → Dart | — | Fired when double-tap detected |

Use `EventChannel` for the `onDoubleTap` stream, `MethodChannel` for the rest.

### macOS Implementation (`HotkeyChannel.swift`)
- Use `CGEventTap` to monitor `keyDown` / `keyUp` for Left Command (keycode 55)
- Track timestamps. If two taps occur within the threshold → fire event to Dart
- Must request accessibility permissions (`AXIsProcessTrusted`)
- If permissions not granted, send an error event so the Dart layer can prompt the user

### Windows Implementation (`hotkey_channel.cpp`)
- Use `SetWindowsHookEx` with `WH_KEYBOARD_LL` to monitor Left Alt (VK_LMENU)
- Same double-tap timestamp logic
- No special permissions needed

---

## Deliverable 3: Audio Capture Service

### Dart Interface (`audio_service.dart`)

```dart
abstract class AudioService {
  /// Stream of raw PCM audio chunks (16kHz, mono, 16-bit).
  /// Chunks should be ~100ms of audio (~3200 bytes at 16kHz/16-bit/mono).
  Stream<Uint8List> get audioStream;

  /// Start capturing audio from the default microphone.
  /// Throws if microphone permission is not granted.
  Future<void> startCapture();

  /// Stop capturing.
  Future<void> stopCapture();

  /// Whether audio is currently being captured.
  bool get isCapturing;

  /// Check if microphone permission is granted.
  Future<bool> hasPermission();

  /// Request microphone permission. Returns true if granted.
  Future<bool> requestPermission();
}
```

### Platform Channel Contract

**Channel name:** `com.yap.audio`

| Method | Direction | Payload | Description |
|---|---|---|---|
| `startCapture` | Dart → Native | — | Begin mic capture |
| `stopCapture` | Dart → Native | — | End mic capture |
| `hasPermission` | Dart → Native | — | Returns `bool` |
| `requestPermission` | Dart → Native | — | Returns `bool` |
| `audioData` | Native → Dart (EventChannel) | `Uint8List` | Raw PCM chunks |
| `error` | Native → Dart | `{ "code": str, "message": str }` | Capture errors |

Audio format: **PCM 16-bit signed little-endian, 16kHz, mono** — this is what AssemblyAI requires.

### macOS Implementation (`AudioCaptureChannel.swift`)
- Use `AVAudioEngine` with an input tap on the input node
- Convert to 16kHz mono PCM if the hardware format differs
- Request microphone permission via `AVCaptureDevice.requestAccess(for: .audio)`

### Windows Implementation (`audio_capture_channel.cpp`)
- Use WASAPI (Windows Audio Session API) in shared or exclusive mode
- Capture from the default audio input device
- Resample to 16kHz mono PCM if needed (use Windows Media Foundation or a simple resampler)

---

## Deliverable 4: Paste Service

### Dart Interface (`paste_service.dart`)

```dart
abstract class PasteService {
  /// Save current clipboard, put [text] on clipboard, simulate Ctrl+V / Cmd+V,
  /// then restore the original clipboard after a short delay.
  /// Returns true if paste was simulated, false if it fell back to clipboard-only.
  Future<bool> pasteText(String text);
}
```

### Platform Channel Contract

**Channel name:** `com.yap.paste`

| Method | Direction | Payload | Description |
|---|---|---|---|
| `paste` | Dart → Native | `{ "text": str }` | Full save-copy-paste-restore cycle |

The native side handles the entire clipboard save → copy → simulate keypress → restore flow because timing is critical and must happen at the OS level.

### macOS Implementation (`PasteChannel.swift`)
- Read current pasteboard contents (`NSPasteboard.general`)
- Set new text on pasteboard
- Use `CGEvent` to simulate Cmd+V keypress
- After ~100ms delay, restore original pasteboard contents
- Requires accessibility permission (same as hotkey — user grants once)

### Windows Implementation (`paste_channel.cpp`)
- Read current clipboard via `OpenClipboard` / `GetClipboardData`
- Set new text via `SetClipboardData`
- Use `SendInput` to simulate Ctrl+V
- After ~100ms delay, restore original clipboard

---

## Deliverable 5: Sound Cue Assets

Include two short WAV files in `assets/sounds/`:
- `record_start.wav` — short, subtle ascending tone (~0.2s)
- `record_stop.wav` — short, distinct descending tone (~0.2s)

These can be simple synthesized tones. Register them in `pubspec.yaml` under `flutter.assets`.

---

## Integration Contracts (What Other Agents Depend On)

### Agent 2 (Audio & Transcription) depends on:
- `AudioService` interface and its `audioStream` of PCM chunks
- `AudioService.startCapture()` / `stopCapture()`

### Agent 3 (LLM & Data) depends on:
- Nothing directly — but will register its providers in the same Riverpod scope

### Agent 4 (UI) depends on:
- `HotkeyService.onDoubleTap` stream to trigger recording
- `PasteService.pasteText()` to paste results
- `AudioService.hasPermission()` / `requestPermission()` for permission flow
- `app_theme.dart` for consistent styling
- `window_manager` being initialized for overlay window management

---

## Testing

- Write unit tests for the Dart service wrappers using mock platform channels
- Each service should have a mock implementation (e.g., `MockHotkeyService`) that other agents can use in their tests
- Test double-tap threshold edge cases (too fast, too slow, exactly at boundary)

---

## Key Constraints

- Audio MUST be 16kHz, mono, 16-bit PCM — AssemblyAI will reject anything else
- Hotkey detection must work when the app is NOT focused (global hook)
- Paste simulation must work in any app (browser, editor, terminal, etc.)
- The overlay window must be always-on-top and frameless
- macOS: accessibility permissions are required for both hotkey and paste — prompt clearly on first use
- The app should have no visible main window — it's a tray app that shows an overlay when activated
