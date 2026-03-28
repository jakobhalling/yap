import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Use an in-memory database for testing.
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Default profile seeding', () {
    test('seeds 4 default profiles on creation', () async {
      final profiles = await db.promptProfileDao.getAllProfiles();
      expect(profiles, hasLength(4));
    });

    test('default profiles have correct slot numbers', () async {
      final profiles = await db.promptProfileDao.getAllProfiles();
      expect(profiles.map((p) => p.slot).toList(), [1, 2, 3, 4]);
    });

    test('slot 1 is Structured prompt', () async {
      final profile = await db.promptProfileDao.getProfile(1);
      expect(profile, isNotNull);
      expect(profile!.name, 'Structured prompt');
      expect(profile.isDefault, true);
      expect(profile.systemPrompt, contains('prompt engineer'));
    });

    test('slot 2 is Clean transcript', () async {
      final profile = await db.promptProfileDao.getProfile(2);
      expect(profile, isNotNull);
      expect(profile!.name, 'Clean transcript');
    });

    test('slot 3 is Fix grammar', () async {
      final profile = await db.promptProfileDao.getProfile(3);
      expect(profile, isNotNull);
      expect(profile!.name, 'Fix grammar');
    });

    test('slot 4 is empty', () async {
      final profile = await db.promptProfileDao.getProfile(4);
      expect(profile, isNotNull);
      expect(profile!.name, '');
      expect(profile.systemPrompt, '');
    });
  });

  group('PromptProfileDao', () {
    test('updateProfile changes name and prompt', () async {
      await db.promptProfileDao.updateProfile(
        1,
        name: 'Custom Name',
        systemPrompt: 'Custom prompt text',
      );

      final profile = await db.promptProfileDao.getProfile(1);
      expect(profile!.name, 'Custom Name');
      expect(profile.systemPrompt, 'Custom prompt text');
      expect(profile.isDefault, false);
    });

    test('resetToDefault restores original content', () async {
      await db.promptProfileDao.updateProfile(1, name: 'Changed');
      await db.promptProfileDao.resetToDefault(1);

      final profile = await db.promptProfileDao.getProfile(1);
      expect(profile!.name, 'Structured prompt');
      expect(profile.isDefault, true);
    });

    test('watchAllProfiles emits updates', () async {
      final stream = db.promptProfileDao.watchAllProfiles();

      // First emission: the 4 default profiles.
      final first = await stream.first;
      expect(first, hasLength(4));

      // Update and check the stream emits again.
      await db.promptProfileDao.updateProfile(1, name: 'Updated');

      // Skip the first emission and get the next one.
      final updated = await stream.skip(1).first;
      expect(updated.first.name, 'Updated');
    });
  });

  group('SettingsDao', () {
    test('get returns null for unset key', () async {
      final value = await db.settingsDao.get('nonexistent_key');
      expect(value, isNull);
    });

    test('set and get round-trips', () async {
      await db.settingsDao.set('test_key', 'test_value');
      final value = await db.settingsDao.get('test_key');
      expect(value, 'test_value');
    });

    test('set overwrites existing value', () async {
      await db.settingsDao.set('key', 'value1');
      await db.settingsDao.set('key', 'value2');
      final value = await db.settingsDao.get('key');
      expect(value, 'value2');
    });

    test('deleteKey removes the key', () async {
      await db.settingsDao.set('key', 'value');
      await db.settingsDao.deleteKey('key');
      final value = await db.settingsDao.get('key');
      expect(value, isNull);
    });

    test('watchKey emits updates', () async {
      final stream = db.settingsDao.watchKey('watch_key');

      // Initially null.
      expect(await stream.first, isNull);

      // Set a value.
      await db.settingsDao.set('watch_key', 'hello');
      final updated = await stream.skip(1).first;
      expect(updated, 'hello');
    });
  });

  group('HistoryDao', () {
    test('insertEntry returns an ID', () async {
      final id = await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('Raw text'),
        pastedText: const Value('Pasted text'),
      ));
      expect(id, greaterThan(0));
    });

    test('getEntry retrieves by ID', () async {
      final id = await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('Raw text'),
        pastedText: const Value('Pasted text'),
        profileName: const Value('Test Profile'),
      ));

      final entry = await db.historyDao.getEntry(id);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, 'Raw text');
      expect(entry.pastedText, 'Pasted text');
      expect(entry.profileName, 'Test Profile');
    });

    test('getAllEntries returns newest first', () async {
      await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('First'),
        pastedText: const Value('First pasted'),
        createdAt: Value(DateTime(2024, 1, 1)),
      ));
      await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('Second'),
        pastedText: const Value('Second pasted'),
        createdAt: Value(DateTime(2024, 1, 2)),
      ));

      final entries = await db.historyDao.getAllEntries();
      expect(entries, hasLength(2));
      expect(entries[0].rawTranscript, 'Second');
      expect(entries[1].rawTranscript, 'First');
    });

    test('getAllEntries respects limit and offset', () async {
      for (int i = 0; i < 10; i++) {
        await db.historyDao.insertEntry(HistoryCompanion(
          rawTranscript: Value('Entry $i'),
          pastedText: Value('Pasted $i'),
        ));
      }

      final page = await db.historyDao.getAllEntries(limit: 3, offset: 2);
      expect(page, hasLength(3));
    });

    test('deleteEntry removes entry', () async {
      final id = await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('To delete'),
        pastedText: const Value('To delete'),
      ));

      await db.historyDao.deleteEntry(id);
      final entry = await db.historyDao.getEntry(id);
      expect(entry, isNull);
    });

    test('clearAll removes all entries', () async {
      await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('Entry 1'),
        pastedText: const Value('Pasted 1'),
      ));
      await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('Entry 2'),
        pastedText: const Value('Pasted 2'),
      ));

      await db.historyDao.clearAll();
      final entries = await db.historyDao.getAllEntries();
      expect(entries, isEmpty);
    });

    test('nullable fields work correctly', () async {
      final id = await db.historyDao.insertEntry(HistoryCompanion(
        rawTranscript: const Value('Raw'),
        pastedText: const Value('Pasted'),
        // Leave nullable fields unset.
      ));

      final entry = await db.historyDao.getEntry(id);
      expect(entry!.profileName, isNull);
      expect(entry.profilePrompt, isNull);
      expect(entry.processedText, isNull);
      expect(entry.durationSeconds, isNull);
    });
  });
}
