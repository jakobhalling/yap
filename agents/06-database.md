# Database

## Overview

SQLite via the `drift` package for type-safe, reactive persistence. Database file stored in the platform-appropriate app data directory.

- **macOS:** `~/Library/Application Support/com.yap/data.db`
- **Windows:** `%APPDATA%\Yap\data.db`

## Tables

### History (`history_table.dart`)
Stores transcription records.

```dart
class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get rawTranscript => text()();
  TextColumn get profileName => text().nullable()();
  TextColumn get profilePrompt => text().nullable()();
  TextColumn get processedText => text().nullable()();
  TextColumn get pastedText => text()();
  RealColumn get durationSeconds => real().nullable()();
}
```

### PromptProfiles (`prompt_profiles_table.dart`)
User-configurable prompt profiles (slots 1-4).

```dart
class PromptProfiles extends Table {
  IntColumn get slot => integer()();      // 1-4
  TextColumn get name => text()();
  TextColumn get systemPrompt => text()();
  BoolColumn get isDefault => boolean()();
}
```

**Default profiles:**
1. **Structured** — Convert speech to well-organized AI prompt
2. **Clean Transcript** — Grammar fix + organization, no summarization
3. **Fix Grammar** — Minimal corrections only
4. **Custom** — User-defined (initially empty)

### Settings (`settings_table.dart`)
Key-value store for app configuration.

```dart
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
}
```

**Settings keys:**
| Key | Default | Description |
|---|---|---|
| `assemblyai_api_key` | — | AssemblyAI API key |
| `anthropic_api_key` | — | Anthropic API key |
| `claude_model` | `"sonnet"` | LLM model selection |
| `double_tap_threshold` | `"400"` | Double-tap window in ms |
| `sound_cues_enabled` | `"true"` | Play sounds on record start/stop |
| `history_enabled` | `"true"` | Save transcription history |
| `auto_start_on_boot` | `"false"` | Launch on system startup |
| `setup_complete` | `"false"` | First-boot wizard completed |
| `microphone_device_id` | — | Selected audio input device |
| `trigger_key` | `"left_command"` (macOS) / `"left_alt"` (Windows) | Hotkey trigger |

## DAOs

- **HistoryDao** — CRUD + watch queries for history list
- **PromptProfileDao** — CRUD for prompt profiles, slot-based lookup
- **SettingsDao** — get/set by key, typed helpers

## Drift Setup

```dart
@DriftDatabase(tables: [History, PromptProfiles, Settings])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;
}
```

Code generation required after table changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```
