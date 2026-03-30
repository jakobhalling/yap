# Platform Channels

## Overview

Yap uses Flutter platform channels to bridge Dart and native code for three capabilities that require OS-level APIs: global hotkey detection, audio capture, and paste simulation.

Each follows the pattern:
1. **Dart abstract interface** — platform-agnostic contract
2. **Dart `*Impl`** — delegates to `MethodChannel` / `EventChannel`
3. **Native handler** — Swift (macOS) or C++ (Windows)

## Hotkey Detection

**Channels:**
- `com.yap.hotkey` (MethodChannel) — start/stop/configure
- `com.yap.hotkey/events` (EventChannel) — double-tap event stream

**Methods:**
| Method | Args | Description |
|---|---|---|
| `start` | `threshold: int`, `triggerKey: String?` | Begin monitoring |
| `stop` | — | Stop monitoring |
| `setThreshold` | `threshold: int` | Update double-tap window (200-600ms) |
| `setTriggerKey` | `key: String` | Change trigger key at runtime |

**Trigger Key Identifiers:**
`left_command`, `right_command`, `left_option`, `right_option`, `left_alt`, `right_alt`, `left_control`, `right_control`, `left_shift`, `right_shift`, `fn`

**macOS Implementation** (`HotkeyChannel.swift`):
- Uses `CGEvent.tapCreate()` with `.cgSessionEventTap` and `.listenOnly`
- Monitors `.flagsChanged` events (modifier key presses)
- Tracks timing via `mach_absolute_time()` for double-tap detection
- Handles `.tapDisabledByTimeout` / `.tapDisabledByUserInput` by re-enabling the tap
- Requires accessibility permission (`AXIsProcessTrusted`)

**Windows Implementation** (`hotkey_channel.cpp`):
- Uses `SetWindowsHookEx(WH_KEYBOARD_LL)` for global keyboard hook
- State machine: idle → first_down → waiting → double-tap
- Uses `QueryPerformanceCounter` for timing

## Audio Capture

**Channels:**
- `com.yap.audio` (MethodChannel) — start/stop capture, device selection
- `com.yap.audio/samples` (EventChannel) — PCM audio data stream
- `com.yap.audio/level` (EventChannel) — VU meter level stream

**Methods:**
| Method | Args | Description |
|---|---|---|
| `startCapture` | `deviceId: String?` | Begin audio capture |
| `stopCapture` | — | Stop capture |
| `getDevices` | — | List available input devices |

**Audio Format:**
- Sample rate: 16,000 Hz
- Channels: 1 (mono)
- Bit depth: 16-bit signed integer
- Byte order: little-endian
- Output: `Uint8List` chunks

**macOS Implementation** (`AudioCaptureChannel.swift`):
- `AVAudioEngine` with input node tap
- Real-time resampling via `AVAudioConverter` to 16kHz mono
- Requires microphone permission (`NSMicrophoneUsageDescription`)

**Windows Implementation** (`audio_capture_channel.cpp`):
- WASAPI for capture in shared or exclusive mode
- Format conversion to 16kHz mono PCM

## Paste Simulation

**Channel:** `com.yap.paste` (MethodChannel)

**Methods:**
| Method | Args | Description |
|---|---|---|
| `paste` | `text: String` | Set clipboard + simulate Cmd/Ctrl+V |

**macOS Implementation** (`PasteChannel.swift`):
1. Save current pasteboard contents
2. Set text to pasteboard
3. Simulate Cmd+V via `CGEvent`
4. Restore original pasteboard after ~150ms delay

**Windows Implementation** (`paste_channel.cpp`):
1. Save clipboard contents
2. Set text to clipboard
3. Simulate Ctrl+V via `SendInput`
4. Restore clipboard after delay

**Note:** Both implementations require accessibility/input permissions to simulate keystrokes.
