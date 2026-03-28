import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/claude/claude_models.dart';
import 'package:yap/services/claude/claude_service.dart';
import 'package:yap/services/database/database.dart';
import 'package:yap/features/processing/processing_service.dart';
import 'package:yap/features/processing/processing_state.dart';
import 'package:yap/features/settings/settings_service.dart';

/// Mock Claude service for testing.
class MockClaudeService implements ClaudeService {
  List<String> chunksToReturn = [];
  Exception? errorToThrow;

  @override
  Stream<String> processTranscript({
    required String transcript,
    required String systemPrompt,
    required String apiKey,
    required String model,
  }) async* {
    if (errorToThrow != null) throw errorToThrow!;
    for (final chunk in chunksToReturn) {
      yield chunk;
    }
  }

  @override
  Future<bool> validateApiKey(String apiKey) async => true;
}

void main() {
  late AppDatabase db;
  late MockClaudeService mockClaude;
  late SettingsServiceImpl settingsService;
  late ProcessingServiceImpl processingService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockClaude = MockClaudeService();
    settingsService = SettingsServiceImpl(db.settingsDao);
    processingService = ProcessingServiceImpl(
      mockClaude,
      db.promptProfileDao,
      settingsService,
    );

    // Set up a valid API key for tests.
    await settingsService.setAnthropicApiKey('test-api-key-123');
  });

  tearDown(() async {
    processingService.dispose();
    await db.close();
  });

  group('ProcessingService', () {
    test('processes transcript through profile successfully', () async {
      mockClaude.chunksToReturn = ['Hello', ' ', 'world'];

      final states = <ProcessingState>[];
      processingService.stateStream.listen(states.add);

      await processingService.processWithProfile(
        transcript: 'Test transcript',
        profileSlot: 1, // Structured prompt (seeded by default)
      );

      // Allow stream events to propagate.
      await Future.delayed(Duration.zero);

      // Should have processing states and a final complete state.
      expect(states.last.status, ProcessingStatus.complete);
      expect(states.last.finalOutput, 'Hello world');
      expect(states.last.profileName, 'Structured prompt');
    });

    test('streams intermediate output', () async {
      mockClaude.chunksToReturn = ['chunk1', 'chunk2', 'chunk3'];

      final outputs = <String>[];
      processingService.stateStream.listen((state) {
        if (state.status == ProcessingStatus.processing) {
          outputs.add(state.streamingOutput);
        }
      });

      await processingService.processWithProfile(
        transcript: 'Test',
        profileSlot: 1,
      );

      await Future.delayed(Duration.zero);

      // Each chunk should have been emitted as partial output.
      expect(outputs, isNotEmpty);
      expect(outputs.last, 'chunk1chunk2chunk3');
    });

    test('throws EmptyProfileException for empty profile', () async {
      expect(
        () => processingService.processWithProfile(
          transcript: 'Test',
          profileSlot: 4, // Slot 4 is empty by default
        ),
        throwsA(isA<EmptyProfileException>()),
      );
    });

    test('throws NoApiKeyException when no key set', () async {
      // Create a fresh DB/service without API key.
      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      final freshSettings = SettingsServiceImpl(freshDb.settingsDao);
      final freshProcessing = ProcessingServiceImpl(
        mockClaude,
        freshDb.promptProfileDao,
        freshSettings,
      );

      expect(
        () => freshProcessing.processWithProfile(
          transcript: 'Test',
          profileSlot: 1,
        ),
        throwsA(isA<NoApiKeyException>()),
      );

      freshProcessing.dispose();
      await freshDb.close();
    });

    test('handles Claude API errors gracefully', () async {
      mockClaude.errorToThrow =
          const ClaudeApiException('Server error', statusCode: 500);

      final states = <ProcessingState>[];
      processingService.stateStream.listen(states.add);

      await processingService.processWithProfile(
        transcript: 'Test',
        profileSlot: 1,
      );

      await Future.delayed(Duration.zero);

      expect(states.last.status, ProcessingStatus.error);
      expect(states.last.errorMessage, contains('Server error'));
    });

    test('reset returns to idle state', () async {
      mockClaude.chunksToReturn = ['Hello'];

      await processingService.processWithProfile(
        transcript: 'Test',
        profileSlot: 1,
      );

      processingService.reset();

      await Future.delayed(Duration.zero);

      expect(processingService.state.status, ProcessingStatus.idle);
    });
  });
}
