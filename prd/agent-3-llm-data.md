# Agent 3 — LLM Processing & Data Layer

## Your Role

You are building the Claude API integration, prompt profile management, settings persistence, history database, and all data models. You provide the services that process transcripts into structured output and persist everything locally.

---

## What You Own

```
lib/
├── services/
│   ├── claude/
│   │   ├── claude_service.dart              # Claude API client interface & implementation
│   │   ├── claude_models.dart               # Request/response models
│   │   └── claude_config.dart               # API configuration
│   └── database/
│       ├── database.dart                    # Drift database definition
│       ├── database.g.dart                  # Generated code (from build_runner)
│       ├── tables/
│       │   ├── history_table.dart           # History table definition
│       │   ├── prompt_profiles_table.dart   # Prompt profiles table
│       │   └── settings_table.dart          # Key-value settings table
│       └── daos/
│           ├── history_dao.dart             # History CRUD operations
│           ├── prompt_profile_dao.dart      # Profile CRUD operations
│           └── settings_dao.dart            # Settings CRUD operations
├── features/
│   ├── processing/
│   │   ├── processing_service.dart          # Orchestrates LLM processing
│   │   ├── processing_state.dart            # State model
│   │   └── processing_providers.dart        # Riverpod providers
│   ├── settings/
│   │   ├── settings_service.dart            # Settings read/write logic
│   │   └── settings_providers.dart          # Riverpod providers for all settings
│   └── history/
│       ├── history_service.dart             # History read/write logic
│       └── history_providers.dart           # Riverpod providers
├── shared/
│   └── prompts/
│       └── default_prompts.dart             # Default prompt profile text constants
└── test/
    ├── services/
    │   ├── claude_service_test.dart
    │   └── database_test.dart
    └── features/
        ├── processing_service_test.dart
        └── settings_service_test.dart
```

---

## Deliverable 1: Default Prompt Profiles

### Constants (`default_prompts.dart`)

```dart
class DefaultPrompts {
  static const List<PromptProfileData> defaults = [
    PromptProfileData(
      slot: 1,
      name: 'Structured prompt',
      systemPrompt: '''You are a prompt engineer. Take the following transcribed speech and convert it into a well-structured prompt for an AI assistant.

CRITICAL RULES:
- PRESERVE ALL DETAIL AND CONTEXT the speaker provided. The speaker chose to say these things because they matter. Do not summarize, condense, or drop specifics.
- Organize the thoughts logically — group related ideas, add structure (headers, bullets, numbered steps) — but do NOT reduce the content
- If the speaker gave examples, keep them. If they described constraints, keep them. If they gave background context, keep it — context is what makes prompts effective.
- Remove only: filler words (um, uh, like), false starts, self-corrections (use the final version of contradicted statements)
- Remove conversational artifacts ("so basically", "you know what I mean")
- The output should read like a well-organized written prompt that happens to contain the same depth of information as the original speech
- Output only the formatted prompt, no meta-commentary''',
    ),
    PromptProfileData(
      slot: 2,
      name: 'Clean transcript',
      systemPrompt: '''You are a transcript editor. Take the following transcribed speech and clean it up while preserving the full content and the speaker's voice.

CRITICAL RULES:
- Keep ALL the detail, context, and reasoning the speaker provided
- Fix grammar, punctuation, and sentence structure
- Remove filler words, false starts, and repetition
- Resolve self-corrections (keep only final intent)
- Organize into paragraphs by topic — but do not summarize or compress
- Preserve the speaker's tone and word choices where possible
- Output only the cleaned text, no commentary''',
    ),
    PromptProfileData(
      slot: 3,
      name: 'Fix grammar',
      systemPrompt: '''You are a copy editor. Fix grammar, punctuation, and spelling only. Minimal changes. Keep the speaker's exact words and structure. Do not restructure or summarize. Output only the corrected text.''',
    ),
    PromptProfileData(
      slot: 4,
      name: '',
      systemPrompt: '',
    ),
  ];
}
```

---

## Deliverable 2: Database (Drift)

### Database Definition (`database.dart`)

```dart
@DriftDatabase(tables: [History, PromptProfiles, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Seed default prompt profiles
      await _seedDefaultProfiles();
    },
  );
}
```

### History Table (`history_table.dart`)

```dart
class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get rawTranscript => text()();
  TextColumn get profileName => text().nullable()();       // NULL if raw paste
  TextColumn get profilePrompt => text().nullable()();     // Snapshot of prompt used
  TextColumn get processedText => text().nullable()();     // NULL if raw paste
  TextColumn get pastedText => text()();                   // What was actually pasted
  RealColumn get durationSeconds => real().nullable()();   // Recording duration
}
```

### Prompt Profiles Table (`prompt_profiles_table.dart`)

```dart
class PromptProfiles extends Table {
  IntColumn get slot => integer()();          // 1-4
  TextColumn get name => text()();
  TextColumn get systemPrompt => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {slot};
}
```

### Settings Table (`settings_table.dart`)

```dart
/// Simple key-value store for app settings
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
```

### Settings Keys

```dart
class SettingsKeys {
  static const String assemblyAIApiKey = 'assemblyai_api_key';
  static const String anthropicApiKey = 'anthropic_api_key';
  static const String claudeModel = 'claude_model';           // 'haiku', 'sonnet', 'opus'
  static const String doubleTapThreshold = 'double_tap_threshold'; // milliseconds
  static const String soundCuesEnabled = 'sound_cues_enabled';    // 'true'/'false'
  static const String historyEnabled = 'history_enabled';         // 'true'/'false'
  static const String autoStartOnBoot = 'auto_start_on_boot';    // 'true'/'false'
}
```

### DAOs

Each DAO provides typed CRUD methods:

**`history_dao.dart`:**
- `insertEntry(HistoryCompanion entry) → Future<int>`
- `getAllEntries({int limit, int offset}) → Future<List<HistoryEntry>>`
- `getEntry(int id) → Future<HistoryEntry?>`
- `deleteEntry(int id) → Future<void>`
- `clearAll() → Future<void>`
- `watchAllEntries() → Stream<List<HistoryEntry>>` (for reactive UI)

**`prompt_profile_dao.dart`:**
- `getProfile(int slot) → Future<PromptProfile?>`
- `getAllProfiles() → Future<List<PromptProfile>>`
- `updateProfile(int slot, {String? name, String? systemPrompt}) → Future<void>`
- `resetToDefault(int slot) → Future<void>`
- `watchAllProfiles() → Stream<List<PromptProfile>>` (for reactive UI)

**`settings_dao.dart`:**
- `get(String key) → Future<String?>`
- `set(String key, String value) → Future<void>`
- `delete(String key) → Future<void>`
- `watchKey(String key) → Stream<String?>` (for reactive settings)

---

## Deliverable 3: Claude API Service

### Interface & Implementation (`claude_service.dart`)

```dart
abstract class ClaudeService {
  /// Process a transcript with a given system prompt.
  /// Returns a stream of text chunks (for streaming display in the UI).
  Stream<String> processTranscript({
    required String transcript,
    required String systemPrompt,
    required String apiKey,
    required String model,
  });

  /// Validate that an API key works.
  /// Returns true if the key is valid, throws with details if not.
  Future<bool> validateApiKey(String apiKey);
}
```

### Claude API Integration

**Endpoint:** `https://api.anthropic.com/v1/messages`

**Headers:**
```
x-api-key: <api_key>
anthropic-version: 2023-06-01
content-type: application/json
```

**Request body:**
```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 8192,
  "stream": true,
  "system": "<the profile's system prompt>",
  "messages": [
    { "role": "user", "content": "<the full transcript>" }
  ]
}
```

**Streaming response:**
- Use Server-Sent Events (SSE) parsing
- Events of type `content_block_delta` contain `{ "delta": { "text": "..." } }`
- Yield each text delta to the stream
- On `message_stop` event, close the stream

**Model mapping:**
| Setting value | Model ID |
|---|---|
| `haiku` | `claude-haiku-4-5-20251001` |
| `sonnet` | `claude-sonnet-4-20250514` |
| `opus` | `claude-opus-4-20250115` |

**Max tokens logic:**
- Default: 8192
- For long transcripts (>4000 words): use 16384
- Cap at 16384

### Models (`claude_models.dart`)

```dart
class ClaudeRequest {
  final String model;
  final int maxTokens;
  final bool stream;
  final String system;
  final List<ClaudeMessage> messages;

  Map<String, dynamic> toJson();
}

class ClaudeMessage {
  final String role;
  final String content;
}

class ClaudeStreamEvent {
  final String type;           // content_block_delta, message_stop, error, etc.
  final String? text;          // Extracted text delta
  final String? errorMessage;
}
```

### Implementation Details

- Use `dio` with `responseType: ResponseType.stream` for SSE
- Parse the SSE format: lines starting with `data: ` contain JSON
- Handle `[DONE]` or stream completion
- On API errors (rate limit, auth, etc.), throw typed exceptions:
  - `ClaudeAuthException` — invalid API key
  - `ClaudeRateLimitException` — rate limited, include retry-after
  - `ClaudeApiException` — generic API error with message

---

## Deliverable 4: Processing Service

Orchestrates taking a completed transcript and running it through a prompt profile.

### State Model (`processing_state.dart`)

```dart
enum ProcessingStatus {
  idle,         // No processing happening
  processing,   // LLM is generating
  complete,     // Result ready
  error,        // Something went wrong
}

class ProcessingState {
  final ProcessingStatus status;
  final String? profileName;           // Which profile is being used
  final String streamingOutput;        // LLM output so far (grows as chunks arrive)
  final String? finalOutput;           // Complete output when done
  final String? errorMessage;
}
```

### Service (`processing_service.dart`)

```dart
abstract class ProcessingService {
  ProcessingState get state;
  Stream<ProcessingState> get stateStream;

  /// Process a transcript with the given profile slot (1-4).
  /// Looks up the profile, sends to Claude, streams the result.
  Future<void> processWithProfile({
    required String transcript,
    required int profileSlot,
  });

  /// Cancel in-progress processing.
  Future<void> cancel();

  /// Reset to idle state.
  void reset();
}
```

### How It Works

1. `processWithProfile()`:
   - Look up the prompt profile by slot from the database
   - If the profile is empty (slot 4 unconfigured), throw `EmptyProfileException`
   - Get the Anthropic API key and model from settings
   - Call `claudeService.processTranscript(...)` with the profile's system prompt
   - Listen to the stream, updating `streamingOutput` with each chunk
   - When complete, set `status = complete`, `finalOutput` = full text

2. Error handling:
   - If Claude API fails, set `status = error` with the message
   - If no API key, throw `NoApiKeyException`

### Providers (`processing_providers.dart`)

```dart
@riverpod
ProcessingService processingService(ProcessingServiceRef ref) {
  final claudeService = ref.watch(claudeServiceProvider);
  final profileDao = ref.watch(promptProfileDaoProvider);
  final settingsService = ref.watch(settingsServiceProvider);
  return ProcessingServiceImpl(claudeService, profileDao, settingsService);
}

@riverpod
Stream<ProcessingState> processingState(ProcessingStateRef ref) {
  return ref.watch(processingServiceProvider).stateStream;
}
```

---

## Deliverable 5: Settings Service & Providers

### Service (`settings_service.dart`)

```dart
abstract class SettingsService {
  Future<String?> getAssemblyAIApiKey();
  Future<void> setAssemblyAIApiKey(String key);

  Future<String?> getAnthropicApiKey();
  Future<void> setAnthropicApiKey(String key);

  Future<String> getClaudeModel();           // Default: 'sonnet'
  Future<void> setClaudeModel(String model);

  Future<int> getDoubleTapThreshold();       // Default: 400
  Future<void> setDoubleTapThreshold(int ms);

  Future<bool> getSoundCuesEnabled();        // Default: true
  Future<void> setSoundCuesEnabled(bool enabled);

  Future<bool> getHistoryEnabled();          // Default: true
  Future<void> setHistoryEnabled(bool enabled);

  Future<bool> getAutoStartOnBoot();         // Default: false
  Future<void> setAutoStartOnBoot(bool enabled);
}
```

### Key Providers (`settings_providers.dart`)

```dart
/// These are the providers that other agents will use to read settings.

@riverpod
Future<String?> assemblyAIApiKey(AssemblyAIApiKeyRef ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getAssemblyAIApiKey();
}

@riverpod
Future<String?> anthropicApiKey(AnthropicApiKeyRef ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getAnthropicApiKey();
}

@riverpod
Future<String> claudeModel(ClaudeModelRef ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getClaudeModel();
}

@riverpod
Future<int> doubleTapThreshold(DoubleTapThresholdRef ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getDoubleTapThreshold();
}

// ... etc for all settings
```

---

## Deliverable 6: History Service & Providers

### Service (`history_service.dart`)

```dart
abstract class HistoryService {
  /// Save a completed session to history.
  /// Call this after the user pastes (or copies to clipboard).
  Future<void> saveEntry({
    required String rawTranscript,
    String? profileName,
    String? profilePrompt,
    String? processedText,
    required String pastedText,
    double? durationSeconds,
  });

  /// Get all history entries, newest first.
  Future<List<HistoryEntry>> getEntries({int limit = 50, int offset = 0});

  /// Watch entries for reactive UI updates.
  Stream<List<HistoryEntry>> watchEntries();

  /// Get a single entry by ID.
  Future<HistoryEntry?> getEntry(int id);

  /// Delete a single entry.
  Future<void> deleteEntry(int id);

  /// Clear all history.
  Future<void> clearAll();

  /// Check if history recording is enabled.
  Future<bool> isEnabled();
}
```

### Providers (`history_providers.dart`)

```dart
@riverpod
HistoryService historyService(HistoryServiceRef ref) {
  final dao = ref.watch(historyDaoProvider);
  final settings = ref.watch(settingsServiceProvider);
  return HistoryServiceImpl(dao, settings);
}

@riverpod
Stream<List<HistoryEntry>> historyEntries(HistoryEntriesRef ref) {
  return ref.watch(historyServiceProvider).watchEntries();
}
```

---

## Dependencies on Other Agents

### From Agent 1 (Platform Layer):
- `pubspec.yaml` with `drift`, `dio`, `riverpod` dependencies already declared
- Riverpod `ProviderScope` set up in `main.dart`

### From Agent 2 (Audio & Transcription):
- `RecordingState.finalTranscript` — the transcript text that gets passed to `processWithProfile()`

---

## What Other Agents Depend On From You

### Agent 2 (Audio & Transcription) depends on:
- `assemblyAIApiKeyProvider` — to get the API key for AssemblyAI connection

### Agent 4 (UI) depends on:
- `processingServiceProvider` — to call `processWithProfile()` and `cancel()`
- `processingStateProvider` — to display streaming LLM output in the overlay
- `settingsServiceProvider` — to read/write all settings in the settings UI
- `historyEntriesProvider` — to display history list
- `historyServiceProvider` — to delete/clear entries
- `promptProfileDaoProvider` — to read/edit profiles in settings UI
- All settings providers (API keys, model, threshold, etc.)

---

## Testing

- **Claude service tests:** Mock HTTP responses. Test SSE parsing with sample Claude API responses. Test error handling (auth failure, rate limit, network error). Test streaming — verify chunks arrive in order.
- **Database tests:** Use in-memory SQLite. Test all CRUD operations. Test default profile seeding. Test settings get/set. Test history ordering (newest first).
- **Processing service tests:** Mock Claude service and database. Test full flow: look up profile → call Claude → stream result. Test cancellation. Test empty profile handling.
- **Settings service tests:** Test defaults are returned when no value is set. Test persistence round-trips.

---

## Key Constraints

- API keys should NOT be logged or exposed in error messages — redact in exceptions
- The Claude streaming response must be parsed correctly — SSE format with `data: ` prefixes
- Database must be opened in the OS-appropriate app data directory (use `path_provider` to get the path)
- Default profiles must be seeded on first launch (database migration `onCreate`)
- All database operations should be async — never block the UI thread
- History entries capture a snapshot of the prompt used (`profilePrompt`), not a reference to the profile — so the history entry is self-contained even if the user later edits the profile
