# Yap - Claude Code Instructions

## What Is This?

Yap is a cross-platform (macOS & Windows) system tray application for voice-driven text input. User activates with a global hotkey (double-tap modifier key), speaks with real-time streaming transcription (AssemblyAI), optionally processes through Claude with customizable prompt profiles, and pastes the result into any text field.

## Quick Reference

```bash
# Run
flutter run -d macos
flutter run -d windows

# Build release
flutter build macos --release
flutter build windows --release

# Code generation (after modifying Drift tables or Riverpod annotations)
dart run build_runner build --delete-conflicting-outputs

# Tests
flutter test
```

## Architecture

```
lib/
├── main.dart                    # Entry point, window init
├── app.dart                     # Root widget, app mode (loading/setup/tray)
├── utils/constants.dart         # App name, version
├── shared/                      # Theme, default prompts
├── services/                    # Platform-agnostic service layer
│   ├── providers.dart           # Riverpod DI (hotkey, audio, paste)
│   ├── database/                # Drift ORM (tables, DAOs)
│   ├── hotkey/                  # Global hotkey detection
│   ├── audio/                   # Audio capture (16kHz mono PCM)
│   ├── paste/                   # Clipboard + keystroke simulation
│   ├── assemblyai/              # Real-time WebSocket transcription
│   └── claude/                  # HTTP + SSE streaming to Claude API
├── features/                    # Feature modules
│   ├── overlay/                 # Main recording/processing UI + controller
│   ├── recording/               # Recording lifecycle + state
│   ├── processing/              # LLM processing lifecycle + state
│   ├── settings/                # Settings UI + service
│   ├── history/                 # History UI + service
│   ├── tray/                    # System tray icon + menu
│   └── setup/                   # First-boot wizard
macos/Runner/PlatformChannels/   # Swift native code (CGEventTap, AVAudioEngine)
windows/runner/platform_channels/ # C++ native code (WASAPI, SendInput)
```

## Tech Stack

- **Flutter desktop** (macOS + Windows) with **Dart 3.2+**
- **Riverpod** for state management and DI
- **Drift** (SQLite) for persistence (history, settings, prompt profiles)
- **Platform channels** for native APIs (hotkey, audio capture, paste)
- **AssemblyAI** real-time streaming transcription (WebSocket v3)
- **Claude API** with SSE streaming for text processing

## Coding Conventions

- **Service pattern:** Abstract interface + `*Impl` implementation + mock for testing
- **Riverpod providers** in `providers.dart` files per feature/layer
- **Feature-based organization:** Each feature in `lib/features/<name>/` with its own service, state, providers, screen, and widgets/
- **Platform channels:** Named `com.yap.<service>` (e.g., `com.yap.hotkey`, `com.yap.audio/samples`)
- **State classes** use immutable patterns with `copyWith()`
- **Streams** for reactive state (broadcast `StreamController`)
- **No code generation for providers** in current codebase -- manual Riverpod providers preferred
- Keep services stateless where possible; state lives in dedicated state classes

## Key Patterns

### Platform Channel Bridge
Each native capability follows the pattern:
1. Abstract Dart interface (`hotkey_service.dart`)
2. Impl that delegates to `MethodChannel`/`EventChannel` (`hotkey_service_impl.dart`)
3. Native Swift (macOS) or C++ (Windows) handler

### Recording Pipeline
```
Hotkey double-tap → OverlayController → RecordingService
  → AudioService (native capture) + AssemblyAI (WebSocket transcription)
  → Real-time transcript updates → Overlay UI
```

### Processing Pipeline
```
User selects profile (1-4) → ProcessingService
  → ClaudeService (SSE streaming) → streaming output → Overlay UI
  → Enter to paste → PasteService (native) → HistoryService (save)
```

## Versioning & Releases

- Version is auto-incremented by CI — **do not manually bump versions**
- `lib/utils/constants.dart` has `appVersion` (updated by CI from tag)
- `installer/yap.iss` has `MyAppVersion` (updated by CI from tag)
- `pubspec.yaml` version is updated by CI during build (from tag)
- **Release flow:** Push to `main` → GitHub Actions auto-increments patch version from latest tag → creates `vX.Y.Z` tag → triggers the release build pipeline
- For minor/major bumps, manually create a tag (e.g., `v2.0.0`) before pushing

## Important Files

| File | Purpose |
|---|---|
| `lib/features/overlay/overlay_controller.dart` | Central orchestrator for recording/processing/paste |
| `lib/services/providers.dart` | Root-level Riverpod providers |
| `macos/Runner/PlatformChannels/HotkeyChannel.swift` | macOS global hotkey via CGEventTap |
| `macos/Runner/PlatformChannels/AudioCaptureChannel.swift` | macOS audio capture via AVAudioEngine |
| `.github/workflows/release.yml` | Windows installer build + GitHub Release |
| `.github/workflows/auto-tag.yml` | Auto-increments patch version and creates tag on every push to main |

## Agent Specifications

See `agents/` folder for detailed specifications:
- `01-project-overview.md` — High-level architecture and user flow
- `02-project-structure.md` — File layout and organization principles
- `03-tech-stack.md` — Framework, packages, and platform-specific details
- `04-platform-channels.md` — Native macOS/Windows integration specs
- `05-services.md` — Service layer specifications and data flow
- `06-database.md` — SQLite schema and Drift ORM details
