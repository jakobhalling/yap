import '../../services/database/daos/settings_dao.dart';
import '../../services/database/tables/settings_table.dart';

/// Abstract interface for reading and writing app settings.
abstract class SettingsService {
  Future<String?> getAssemblyAIApiKey();
  Future<void> setAssemblyAIApiKey(String key);

  Future<String?> getAnthropicApiKey();
  Future<void> setAnthropicApiKey(String key);

  Future<String> getClaudeModel(); // Default: 'sonnet'
  Future<void> setClaudeModel(String model);

  Future<int> getDoubleTapThreshold(); // Default: 400
  Future<void> setDoubleTapThreshold(int ms);

  Future<bool> getSoundCuesEnabled(); // Default: true
  Future<void> setSoundCuesEnabled(bool enabled);

  Future<bool> getHistoryEnabled(); // Default: true
  Future<void> setHistoryEnabled(bool enabled);

  Future<bool> getAutoStartOnBoot(); // Default: false
  Future<void> setAutoStartOnBoot(bool enabled);

  Future<bool> isSetupComplete(); // Default: false
  Future<void> setSetupComplete(bool complete);

  Future<String?> getMicrophoneDeviceId(); // Default: null (system default)
  Future<void> setMicrophoneDeviceId(String? deviceId);
}

/// Production implementation backed by the settings DAO (key-value store).
class SettingsServiceImpl implements SettingsService {
  final SettingsDao _dao;

  SettingsServiceImpl(this._dao);

  // --- AssemblyAI API Key ---

  @override
  Future<String?> getAssemblyAIApiKey() =>
      _dao.get(SettingsKeys.assemblyAIApiKey);

  @override
  Future<void> setAssemblyAIApiKey(String key) =>
      _dao.set(SettingsKeys.assemblyAIApiKey, key);

  // --- Anthropic API Key ---

  @override
  Future<String?> getAnthropicApiKey() =>
      _dao.get(SettingsKeys.anthropicApiKey);

  @override
  Future<void> setAnthropicApiKey(String key) =>
      _dao.set(SettingsKeys.anthropicApiKey, key);

  // --- Claude Model ---

  @override
  Future<String> getClaudeModel() async {
    return await _dao.get(SettingsKeys.claudeModel) ?? 'sonnet';
  }

  @override
  Future<void> setClaudeModel(String model) =>
      _dao.set(SettingsKeys.claudeModel, model);

  // --- Double Tap Threshold ---

  @override
  Future<int> getDoubleTapThreshold() async {
    final value = await _dao.get(SettingsKeys.doubleTapThreshold);
    if (value == null) return 400;
    return int.tryParse(value) ?? 400;
  }

  @override
  Future<void> setDoubleTapThreshold(int ms) =>
      _dao.set(SettingsKeys.doubleTapThreshold, ms.toString());

  // --- Sound Cues ---

  @override
  Future<bool> getSoundCuesEnabled() async {
    final value = await _dao.get(SettingsKeys.soundCuesEnabled);
    if (value == null) return true;
    return value == 'true';
  }

  @override
  Future<void> setSoundCuesEnabled(bool enabled) =>
      _dao.set(SettingsKeys.soundCuesEnabled, enabled.toString());

  // --- History Enabled ---

  @override
  Future<bool> getHistoryEnabled() async {
    final value = await _dao.get(SettingsKeys.historyEnabled);
    if (value == null) return true;
    return value == 'true';
  }

  @override
  Future<void> setHistoryEnabled(bool enabled) =>
      _dao.set(SettingsKeys.historyEnabled, enabled.toString());

  // --- Auto Start On Boot ---

  @override
  Future<bool> getAutoStartOnBoot() async {
    final value = await _dao.get(SettingsKeys.autoStartOnBoot);
    if (value == null) return false;
    return value == 'true';
  }

  @override
  Future<void> setAutoStartOnBoot(bool enabled) =>
      _dao.set(SettingsKeys.autoStartOnBoot, enabled.toString());

  // --- Setup Complete ---

  @override
  Future<bool> isSetupComplete() async {
    final value = await _dao.get(SettingsKeys.setupComplete);
    if (value == null) return false;
    return value == 'true';
  }

  @override
  Future<void> setSetupComplete(bool complete) =>
      _dao.set(SettingsKeys.setupComplete, complete.toString());

  // --- Microphone Device ---

  @override
  Future<String?> getMicrophoneDeviceId() =>
      _dao.get(SettingsKeys.microphoneDeviceId);

  @override
  Future<void> setMicrophoneDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return _dao.deleteKey(SettingsKeys.microphoneDeviceId);
    }
    return _dao.set(SettingsKeys.microphoneDeviceId, deviceId);
  }
}
