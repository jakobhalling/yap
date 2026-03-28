# Agent 4 — UI & System Integration

## Your Role

You are building all user-facing UI and the system tray integration. You consume services and state from Agents 1–3 and wire everything into a cohesive user experience. You own the overlay window, settings screen, history screen, system tray menu, and all keyboard interaction.

---

## What You Own

```
lib/
├── features/
│   ├── overlay/
│   │   ├── overlay_window.dart              # Overlay window management
│   │   ├── overlay_screen.dart              # Main overlay widget (all states)
│   │   ├── widgets/
│   │   │   ├── waveform_animation.dart      # Soundwave animation during recording
│   │   │   ├── transcript_view.dart         # Scrollable transcript display
│   │   │   ├── profile_selector.dart        # Profile options bar (1-4, Enter, Esc)
│   │   │   ├── processing_indicator.dart    # LLM processing spinner + streaming text
│   │   │   └── elapsed_timer.dart           # Recording duration display
│   │   └── overlay_controller.dart          # Orchestrates the full user flow
│   ├── settings/
│   │   ├── settings_screen.dart             # Settings window/dialog
│   │   └── widgets/
│   │       ├── api_keys_section.dart        # API key inputs with validation
│   │       ├── profiles_section.dart        # Profile editor (name + prompt textarea)
│   │       ├── general_section.dart         # Double-tap speed, model, sound cues
│   │       └── history_section.dart         # History toggle, clear button
│   ├── history/
│   │   ├── history_screen.dart              # History list view
│   │   └── widgets/
│   │       ├── history_list_item.dart       # Single history entry (collapsed)
│   │       └── history_detail_view.dart     # Expanded entry with full text
│   └── tray/
│       ├── tray_service.dart                # System tray setup and menu
│       └── tray_providers.dart              # Riverpod providers
└── test/
    └── features/
        ├── overlay/
        │   └── overlay_controller_test.dart
        └── widgets/
            └── widget_tests.dart
```

---

## Deliverable 1: System Tray

### Tray Service (`tray_service.dart`)

Set up the system tray icon and context menu using the `system_tray` package.

**Tray Icon:**
- Idle: microphone icon (monochrome, OS-appropriate)
- Recording: microphone with red dot or red-tinted icon

**Menu Items:**
```
Yap                    (disabled title)
──────────────────────
Start Recording        (or "Stop Recording" when active)
──────────────────────
History
Settings
──────────────────────
About
Quit
```

**Behavior:**
- "Start/Stop Recording" triggers the same flow as the double-tap hotkey
- "History" opens the history screen
- "Settings" opens the settings screen
- "About" shows a simple about dialog (app name, version)
- "Quit" closes the application
- Update the menu item text dynamically: "Start Recording" ↔ "Stop Recording"

### Provider (`tray_providers.dart`)

```dart
@riverpod
TrayService trayService(TrayServiceRef ref) {
  final recordingService = ref.watch(recordingServiceProvider);
  return TrayService(recordingService);
}
```

---

## Deliverable 2: Overlay Window

### Window Management (`overlay_window.dart`)

The overlay is a **separate window** managed via `window_manager`. It is NOT the main app window.

**Window properties:**
- Frameless (no title bar)
- Always on top
- Not shown in taskbar/dock
- Positioned at top-center of screen
- Width: ~600px (adapts to content, max ~800px)
- Height: dynamic, grows downward as transcript grows (min ~200px, max ~60% screen height)
- Rounded corners
- Semi-transparent background (slight blur if possible, otherwise solid with opacity)

**Lifecycle:**
- Created on first use, hidden when not needed (reuse, don't recreate)
- `show()` — position at top-center, show with animation (fade in + slide down)
- `hide()` — fade out, then hide

```dart
class OverlayWindow {
  Future<void> show();
  Future<void> hide();
  Future<void> updateSize(double height);
  bool get isVisible;
}
```

### Overlay Screen (`overlay_screen.dart`)

The main widget that renders inside the overlay window. It switches between states based on the recording and processing state.

**State machine:**

```
[idle/hidden]
    │ double-tap
    ▼
[recording] ──── double-tap ───► [transcript_complete]
    │                                │
    │                           Enter │ 1-4        Esc
    │                             │    │            │
    │                             ▼    ▼            ▼
    │                         [paste] [processing] [cancel→hide]
    │                                  │
    │                             complete
    │                                  │
    │                                  ▼
    │                            [ready_to_paste]
    │                                │         │
    │                           Enter│     Esc │
    │                                ▼         ▼
    │                            [paste]  [cancel→hide]
```

### Overlay Controller (`overlay_controller.dart`)

Orchestrates the full user flow. This is the central coordinator.

```dart
class OverlayController {
  // Dependencies (injected via Riverpod)
  final RecordingService recordingService;
  final ProcessingService processingService;
  final PasteService pasteService;
  final HistoryService historyService;
  final HotkeyService hotkeyService;
  final OverlayWindow overlayWindow;

  OverlayState get state;
  Stream<OverlayState> get stateStream;

  /// Call once at app startup. Listens to hotkey events.
  void initialize() {
    hotkeyService.onDoubleTap.listen((_) => _handleDoubleTap());
  }

  /// Handle double-tap: toggle recording on/off
  void _handleDoubleTap();

  /// Handle keyboard input while overlay is shown
  void handleKey(LogicalKeyboardKey key);

  /// Process transcript with a profile (called when user presses 1-4)
  Future<void> processWithProfile(int slot);

  /// Paste the current result and close overlay
  Future<void> pasteAndClose();

  /// Cancel and close overlay
  void cancel();
}
```

**Overlay state:**
```dart
enum OverlayPhase {
  hidden,
  recording,
  transcriptComplete,
  processing,
  readyToPaste,
  error,
}

class OverlayState {
  final OverlayPhase phase;
  final String transcript;           // Current transcript text
  final String processedText;        // LLM output (streaming or complete)
  final String? profileName;         // Profile being used
  final Duration elapsed;            // Recording duration
  final String? errorMessage;
  final List<ProfileOption> profiles; // Available profiles for selection
}

class ProfileOption {
  final int slot;
  final String name;
  final bool isEmpty;                // True if no prompt configured
}
```

**Full flow implementation:**

1. **Double-tap while hidden:**
   - Play start sound
   - Show overlay window
   - Call `recordingService.startRecording()`
   - Set phase = `recording`
   - Listen to `recordingService.stateStream` to update transcript in real-time

2. **Double-tap while recording:**
   - Play stop sound
   - Call `recordingService.stopRecording()`
   - Wait for `RecordingState.status == complete`
   - Load available profiles from database
   - Set phase = `transcriptComplete`
   - Focus keyboard on overlay for key input

3. **User presses `Enter` (transcript complete):**
   - Paste raw transcript via `pasteService.pasteText(transcript)`
   - Save to history (if enabled): raw paste, no profile
   - Hide overlay

4. **User presses `1`–`4` (transcript complete):**
   - If that profile slot is empty, do nothing (or show brief "not configured" message)
   - Set phase = `processing`
   - Call `processingService.processWithProfile(transcript, slot)`
   - Listen to `processingService.stateStream` to show streaming output
   - When complete, set phase = `readyToPaste`

5. **User presses `Enter` (ready to paste):**
   - Paste processed text via `pasteService.pasteText(processedText)`
   - Save to history (if enabled): raw transcript + profile name + processed text
   - Hide overlay

6. **User presses `Esc` (any state):**
   - Cancel any in-progress recording or processing
   - Hide overlay
   - Reset all state

7. **Error at any step:**
   - Set phase = `error` with message
   - Show error in overlay
   - If it's a Claude error, offer to paste raw transcript instead (show "Enter to paste raw")
   - Esc to dismiss

---

## Deliverable 3: Overlay Widgets

### Waveform Animation (`waveform_animation.dart`)
- Animated bars that respond to recording state (not actual audio levels — just a visual indicator)
- 5-7 vertical bars that animate up and down at different speeds
- Red/accent color to indicate recording
- Centered above the transcript area

### Transcript View (`transcript_view.dart`)
- Scrollable text area
- Auto-scrolls to bottom as new text appears during recording
- Text style: monospaced or clean sans-serif, readable size (~16px)
- Partial transcript text shown in slightly lighter color than final text
- When in `transcriptComplete` state, full transcript is shown

### Profile Selector (`profile_selector.dart`)
- Horizontal bar at the bottom of the overlay
- Shows: `Enter: Paste raw  │  1 · Structured prompt  2 · Clean transcript  3 · Fix grammar  4 · (empty)`
- Empty/unconfigured profiles shown in muted text
- Current selection (if processing) highlighted

### Processing Indicator (`processing_indicator.dart`)
- Shows "Processing with: [profile name]" header
- Streaming text area that grows as LLM output arrives
- Subtle loading spinner/animation next to the header while streaming
- When complete, spinner disappears

### Elapsed Timer (`elapsed_timer.dart`)
- Shows recording duration: "0:05", "1:23", etc.
- Updates every second
- Shown during recording phase, top-right of overlay

---

## Deliverable 4: Settings Screen

A separate window (not the overlay). Opened from tray menu → "Settings".

### Layout

Tabbed or sectioned layout:

**API Keys Section (`api_keys_section.dart`):**
- AssemblyAI API key: password text field + "Test" button
  - Test button calls the AssemblyAI API to validate the key
  - Shows green checkmark or red X with error message
- Anthropic API key: password text field + "Test" button
  - Test button calls `claudeService.validateApiKey()`
  - Shows green checkmark or red X

**Profiles Section (`profiles_section.dart`):**
- List of 4 profiles, each with:
  - Name text field (short, displayed in overlay)
  - System prompt text area (multi-line, resizable)
  - "Reset to default" button (only for slots 1-3)
- Preview of how the profile appears in the overlay

**General Section (`general_section.dart`):**
- Double-tap speed: slider, 200ms–600ms, shows current value
  - On change: update via `hotkeyService.setDoubleTapThreshold()`
- Claude model: dropdown — Haiku / Sonnet / Opus
- Sound cues: toggle switch
- Auto-start on boot: toggle switch

**History Section (`history_section.dart`):**
- Enable/disable history recording: toggle switch
- "Clear all history" button with confirmation dialog
- Shows storage location path (read-only)

### Behavior
- All changes save immediately (no explicit save button)
- API key fields are masked (show/hide toggle)
- Window is a standard resizable window with title bar

---

## Deliverable 5: History Screen

A separate window opened from tray menu → "History".

### History List (`history_screen.dart`)
- Scrollable list, newest entries first
- Each item shows: timestamp, profile used (or "Raw"), first ~100 chars of pasted text
- Click to expand/navigate to detail view

### History List Item (`history_list_item.dart`)
- Compact row: `[2024-03-15 2:30 PM]  Structured prompt  •  "You are building a Flutter app that..."`
- Subtle visual distinction between raw pastes and processed entries

### History Detail View (`history_detail_view.dart`)
- Full view of a single entry:
  - Timestamp and duration
  - Profile name and prompt used (collapsible)
  - Raw transcript (collapsible section)
  - Processed text (if applicable)
  - Final pasted text
  - "Copy to clipboard" button for each text section
- Back button to return to list

---

## Deliverable 6: Keyboard Handling

The overlay must capture keyboard input when visible. This is critical — the whole UX depends on fast keyboard interaction.

### Key Bindings (while overlay is visible)

| Key | Transcript Complete | Processing | Ready to Paste | Error |
|---|---|---|---|---|
| `Enter` | Paste raw transcript | — | Paste processed text | Paste raw transcript (if available) |
| `1` | Process with profile 1 | — | — | — |
| `2` | Process with profile 2 | — | — | — |
| `3` | Process with profile 3 | — | — | — |
| `4` | Process with profile 4 | — | — | — |
| `Esc` | Cancel & hide | Cancel processing & hide | Cancel & hide | Dismiss & hide |

### Implementation
- Use `RawKeyboardListener` or `FocusNode` with `onKey` callback on the overlay widget
- The overlay must request and maintain keyboard focus when shown
- Keys should respond on keyDown, not keyUp, for snappy feel

---

## Dependencies on Other Agents

### From Agent 1 (Platform Layer):
- `HotkeyService` — `onDoubleTap` stream to trigger recording
- `PasteService` — `pasteText()` to paste results
- `AudioService` — `hasPermission()` / `requestPermission()` for first-launch flow
- `app_theme.dart` — light/dark theme
- `window_manager` initialized and ready
- Sound assets in `assets/sounds/`

### From Agent 2 (Audio & Transcription):
- `RecordingService` — `startRecording()` / `stopRecording()` / `cancelRecording()`
- `RecordingState` — `status`, `currentTranscript`, `elapsed`, `errorMessage`
- `recordingServiceProvider` and `recordingStateProvider`

### From Agent 3 (LLM & Data):
- `ProcessingService` — `processWithProfile()` / `cancel()` / `reset()`
- `ProcessingState` — `status`, `streamingOutput`, `finalOutput`, `errorMessage`
- `SettingsService` — all getters/setters for the settings screen
- `HistoryService` — `saveEntry()`, `watchEntries()`, `deleteEntry()`, `clearAll()`
- `PromptProfileDao` — `getAllProfiles()`, `updateProfile()`, `resetToDefault()`
- `ClaudeService` — `validateApiKey()` for the settings test button
- All settings providers

---

## What Other Agents Depend On From You

Nothing — you are the consumer. All other agents provide services; you wire them into the UI.

---

## Sound Cue Integration

Use the `audioplayers` package to play sounds:
- On recording start: play `assets/sounds/record_start.wav`
- On recording stop: play `assets/sounds/record_stop.wav`
- Respect the `soundCuesEnabled` setting — check before playing

---

## Error UX

| Error | UI Behavior |
|---|---|
| No API key | Show inline message in overlay: "API key not configured" + "Press S to open Settings" (or link) |
| No mic permission | Show overlay with: "Microphone access needed" + platform-specific instructions |
| No internet | Show in overlay: "No connection — check your network" |
| AssemblyAI error | Show error + "Esc to dismiss" |
| Claude error | Show error + "Enter to paste raw transcript" + "Esc to dismiss" |
| Paste fails | Copy to clipboard, show brief notification: "Copied to clipboard (no text field detected)" |

---

## Visual Design Notes

- **Overlay background:** Semi-transparent dark (dark mode) or light (light mode) with blur if available
- **Rounded corners:** ~12px border radius
- **Shadow:** Subtle drop shadow for depth
- **Text:** System font, ~15-16px for transcript, ~13px for UI labels
- **Colors:** Follow OS accent color for highlights. Red for recording indicator. Muted for disabled profiles.
- **Animations:** Keep them subtle and fast — the app should feel snappy, not flashy
  - Overlay show: 150ms fade + slide
  - Overlay hide: 100ms fade
  - Waveform: continuous gentle animation
  - Transcript text: no animation, just appears (immediate is better for real-time text)

---

## Testing

- **Overlay controller tests:** Mock all services. Test the full state machine: idle → recording → complete → process → ready → paste. Test all key handlers. Test error flows. Test cancellation at each stage.
- **Widget tests:** Test each widget renders correctly for each state. Test that keyboard events are captured. Test that profile selector shows correct profiles.
- **Integration note:** Full end-to-end testing requires all agents' code. Focus your tests on the UI logic and state transitions with mocked services.

---

## Key Constraints

- The overlay MUST capture keyboard focus immediately when shown — if the user presses `1` and nothing happens, the UX is broken
- The overlay must never steal focus from the underlying app unnecessarily — only when it's actively shown
- Auto-scroll during recording must be smooth, not jumpy
- The settings and history windows are standard windows (with title bars) — only the overlay is frameless
- All windows follow OS light/dark mode — use `MediaQuery.platformBrightness`
- Keep the overlay rendering lightweight — it's always on top, so janky rendering is very visible
