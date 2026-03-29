import 'package:drift/drift.dart';

/// Simple key-value store for app settings.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Well-known settings keys.
class SettingsKeys {
  static const String assemblyAIApiKey = 'assemblyai_api_key';
  static const String anthropicApiKey = 'anthropic_api_key';
  static const String claudeModel = 'claude_model'; // 'haiku', 'sonnet', 'opus'
  static const String doubleTapThreshold =
      'double_tap_threshold'; // milliseconds
  static const String soundCuesEnabled =
      'sound_cues_enabled'; // 'true'/'false'
  static const String historyEnabled = 'history_enabled'; // 'true'/'false'
  static const String autoStartOnBoot =
      'auto_start_on_boot'; // 'true'/'false'
  static const String setupComplete = 'setup_complete'; // 'true'/'false'
  static const String microphoneDeviceId = 'microphone_device_id'; // device ID string
  static const String triggerKey = 'trigger_key'; // modifier key identifier string
}
