import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/database/daos/settings_dao.dart';
import '../processing/processing_providers.dart';
import 'settings_service.dart';

/// Provider for the SettingsDao.
final settingsDaoProvider = Provider<SettingsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.settingsDao;
});

/// Provider for the SettingsService.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final dao = ref.watch(settingsDaoProvider);
  return SettingsServiceImpl(dao);
});

/// Async provider for the AssemblyAI API key.
final assemblyAIApiKeyProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getAssemblyAIApiKey();
});

/// Async provider for the Anthropic API key.
final anthropicApiKeyProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getAnthropicApiKey();
});

/// Async provider for the selected Claude model name.
final claudeModelProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getClaudeModel();
});

/// Async provider for the double-tap threshold in milliseconds.
final doubleTapThresholdProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getDoubleTapThreshold();
});

/// Async provider for whether sound cues are enabled.
final soundCuesEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getSoundCuesEnabled();
});

/// Async provider for whether history recording is enabled.
final historyEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getHistoryEnabled();
});

/// Async provider for whether auto-start on boot is enabled.
final autoStartOnBootProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getAutoStartOnBoot();
});
