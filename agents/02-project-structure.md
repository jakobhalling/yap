# Project Structure

## Layout

```
yap/
├── CLAUDE.md                          # Claude Code instructions
├── PRD.md                             # Product requirements document
├── README.md                          # User-facing readme
├── pubspec.yaml                       # Flutter dependencies + version
├── agents/                            # Agent specification files
├── lib/
│   ├── main.dart                      # Entry point; window manager init
│   ├── app.dart                       # Root widget; mode management (loading/setup/tray)
│   ├── utils/
│   │   └── constants.dart             # App name, version constants
│   ├── shared/
│   │   ├── theme/
│   │   │   └── app_theme.dart         # Material light/dark themes
│   │   └── prompts/
│   │       └── default_prompts.dart   # Built-in prompt profiles (slots 1-4)
│   ├── services/                      # Platform-agnostic service layer
│   │   ├── providers.dart             # Root Riverpod providers (hotkey, audio, paste)
│   │   ├── database/                  # Drift ORM
│   │   │   ├── database.dart          # AppDatabase definition
│   │   │   ├── tables/               # Table definitions
│   │   │   └── daos/                 # Data access objects
│   │   ├── hotkey/                    # Global hotkey (abstract + impl + mock)
│   │   ├── audio/                     # Audio capture (abstract + impl + mock)
│   │   ├── paste/                     # Paste simulation (abstract + impl + mock)
│   │   ├── assemblyai/               # Real-time transcription service
│   │   ├── claude/                    # LLM processing service
│   │   ├── startup_service.dart       # Launch-on-boot config
│   │   └── update_service.dart        # Auto-update checking
│   └── features/                      # Feature modules (UI + logic)
│       ├── overlay/                   # Recording/processing overlay
│       │   ├── overlay_controller.dart # Central orchestrator
│       │   ├── overlay_window.dart    # Window show/hide/position
│       │   ├── overlay_screen.dart    # Main overlay UI
│       │   └── widgets/              # Waveform, transcript, timer, etc.
│       ├── recording/                 # Recording lifecycle
│       ├── processing/                # LLM processing lifecycle
│       ├── settings/                  # Settings UI + service
│       ├── history/                   # History UI + service
│       ├── tray/                      # System tray management
│       └── setup/                     # First-boot wizard
├── macos/
│   └── Runner/
│       ├── AppDelegate.swift          # Registers platform channels
│       └── PlatformChannels/
│           ├── HotkeyChannel.swift    # CGEventTap double-tap detection
│           ├── AudioCaptureChannel.swift # AVAudioEngine → 16kHz PCM
│           └── PasteChannel.swift     # CGEvent Cmd+V simulation
├── windows/
│   └── runner/
│       └── platform_channels/
│           ├── hotkey_channel.h/cpp   # SetWindowsHookEx double-tap
│           ├── audio_capture_channel.h/cpp # WASAPI capture
│           └── paste_channel.h/cpp    # SendInput Ctrl+V
├── assets/
│   ├── icons/                         # Tray icons (idle + recording)
│   └── sounds/                        # Record start/stop cues
├── installer/
│   └── yap.iss                        # Inno Setup script (Windows)
├── scripts/
│   └── build_installer.ps1            # Windows installer build script
├── test/                              # Unit and widget tests
└── .github/
    └── workflows/
        ├── release.yml                # Windows build + GitHub Release (tag-triggered)
        └── auto-tag.yml               # Auto-tag from pubspec.yaml version on push to main
```

## Key Principles

- **Feature-based organization:** Each feature owns its screen, widgets, service, state, and providers
- **Service abstraction:** Abstract interface → `*Impl` → mock (enables testing without platform)
- **Platform code isolation:** All native code in `PlatformChannels/` (macOS) and `platform_channels/` (Windows)
- **Models are plain Dart:** No Flutter imports in data models or state classes
- **Single window, multiple modes:** One Flutter window managed by `window_manager` — shown as overlay, settings, or history
- **Riverpod for DI:** All services instantiated via providers with lifecycle management
