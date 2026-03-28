import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/database/database.dart';
import 'package:yap/features/settings/settings_service.dart';

void main() {
  late AppDatabase db;
  late SettingsServiceImpl service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = SettingsServiceImpl(db.settingsDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsService defaults', () {
    test('getClaudeModel defaults to sonnet', () async {
      expect(await service.getClaudeModel(), 'sonnet');
    });

    test('getDoubleTapThreshold defaults to 400', () async {
      expect(await service.getDoubleTapThreshold(), 400);
    });

    test('getSoundCuesEnabled defaults to true', () async {
      expect(await service.getSoundCuesEnabled(), true);
    });

    test('getHistoryEnabled defaults to true', () async {
      expect(await service.getHistoryEnabled(), true);
    });

    test('getAutoStartOnBoot defaults to false', () async {
      expect(await service.getAutoStartOnBoot(), false);
    });

    test('getAssemblyAIApiKey defaults to null', () async {
      expect(await service.getAssemblyAIApiKey(), isNull);
    });

    test('getAnthropicApiKey defaults to null', () async {
      expect(await service.getAnthropicApiKey(), isNull);
    });
  });

  group('SettingsService persistence', () {
    test('setClaudeModel persists value', () async {
      await service.setClaudeModel('opus');
      expect(await service.getClaudeModel(), 'opus');
    });

    test('setDoubleTapThreshold persists value', () async {
      await service.setDoubleTapThreshold(300);
      expect(await service.getDoubleTapThreshold(), 300);
    });

    test('setSoundCuesEnabled persists value', () async {
      await service.setSoundCuesEnabled(false);
      expect(await service.getSoundCuesEnabled(), false);
    });

    test('setHistoryEnabled persists value', () async {
      await service.setHistoryEnabled(false);
      expect(await service.getHistoryEnabled(), false);
    });

    test('setAutoStartOnBoot persists value', () async {
      await service.setAutoStartOnBoot(true);
      expect(await service.getAutoStartOnBoot(), true);
    });

    test('setAssemblyAIApiKey round-trips', () async {
      await service.setAssemblyAIApiKey('aai-test-key-123');
      expect(await service.getAssemblyAIApiKey(), 'aai-test-key-123');
    });

    test('setAnthropicApiKey round-trips', () async {
      await service.setAnthropicApiKey('sk-ant-test-key-123');
      expect(await service.getAnthropicApiKey(), 'sk-ant-test-key-123');
    });

    test('overwriting a setting keeps latest value', () async {
      await service.setClaudeModel('haiku');
      await service.setClaudeModel('opus');
      expect(await service.getClaudeModel(), 'opus');
    });
  });

  group('SettingsService boolean edge cases', () {
    test('handles corrupted boolean values gracefully', () async {
      // Write a non-boolean string directly to the DAO.
      await db.settingsDao.set('sound_cues_enabled', 'not_a_bool');
      // Should return false since it's not 'true'.
      expect(await service.getSoundCuesEnabled(), false);
    });

    test('handles corrupted int values gracefully', () async {
      await db.settingsDao.set('double_tap_threshold', 'not_a_number');
      // Should return the default 400.
      expect(await service.getDoubleTapThreshold(), 400);
    });
  });
}
