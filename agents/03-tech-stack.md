# Tech Stack

## Framework

- **Flutter** desktop (macOS + Windows), stable channel
- **Dart 3.2+**
- Minimum macOS deployment target: 10.15

## Key Packages

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.4.0 | State management and DI |
| `riverpod_annotation` | ^2.3.0 | Riverpod code generation annotations |
| `drift` | ^2.14.0 | Type-safe SQLite ORM |
| `sqlite3_flutter_libs` | ^0.5.0 | SQLite native bindings |
| `web_socket_channel` | ^2.4.0 | WebSocket client (AssemblyAI) |
| `dio` | ^5.4.0 | HTTP client (Claude API) |
| `window_manager` | ^0.3.7 | Window control (show/hide/size/position) |
| `system_tray` | ^2.0.3 | System tray icon + context menu |
| `screen_retriever` | ^0.1.9 | Screen geometry for overlay positioning |
| `audioplayers` | ^5.2.0 | Sound cues (record start/stop) |
| `path_provider` | ^2.1.0 | Platform-appropriate data directories |
| `shared_preferences` | ^2.2.0 | Simple key-value storage |
| `google_fonts` | ^6.1.0 | Typography (Inter, JetBrains Mono) |

## Dev Dependencies

| Package | Purpose |
|---|---|
| `build_runner` | Code generation runner |
| `drift_dev` | Drift ORM code generation |
| `riverpod_generator` | Riverpod provider generation |
| `flutter_lints` | Lint rules |

## Platform-Specific

### macOS (Swift)
- **CGEventTap** — global keyboard event interception (accessibility permission required)
- **AVAudioEngine** — audio capture with real-time resampling to 16kHz mono
- **CGEvent** — keystroke simulation for Cmd+V paste
- **AXIsProcessTrusted** — accessibility permission checking/prompting
- Entitlements: microphone access, network client, audio input

### Windows (C++)
- **SetWindowsHookEx** — global keyboard hook (WH_KEYBOARD_LL)
- **WASAPI** — audio capture with format conversion
- **SendInput** — keystroke simulation for Ctrl+V paste

## External APIs

### AssemblyAI (Real-Time Transcription)
- Token endpoint: `https://streaming.assemblyai.com/v3/token`
- WebSocket: `wss://streaming.assemblyai.com/v3/ws`
- Audio format: 16kHz, mono, 16-bit signed PCM (little-endian)
- Speech model: `universal-streaming-english`

### Claude (Text Processing)
- Endpoint: `https://api.anthropic.com/v1/messages`
- API version: `2023-06-01`
- Models: haiku, sonnet (default), opus
- Streaming: SSE (`stream: true`)
- Max tokens: 8192 default, 16384 for transcripts >4000 words

## Build & Run

```bash
# Development
flutter run -d macos
flutter run -d windows

# Release builds
flutter build macos --release
flutter build windows --release

# Code generation (after Drift/Riverpod changes)
dart run build_runner build --delete-conflicting-outputs

# Windows installer
.\scripts\build_installer.ps1
```

## Release Pipeline

1. Bump version in `pubspec.yaml`
2. Push to `main`
3. `auto-tag.yml` workflow creates `vX.Y.Z` git tag
4. `release.yml` workflow triggers on tag → builds Windows installer → creates GitHub Release
