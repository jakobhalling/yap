import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/claude/claude_service.dart';
import '../../services/database/database.dart';
import '../../services/database/daos/prompt_profile_dao.dart';
import '../settings/settings_providers.dart';
import 'processing_service.dart';
import 'processing_state.dart';

/// Provider for the Claude API client.
final claudeServiceProvider = Provider<ClaudeService>((ref) {
  return ClaudeServiceImpl();
});

/// Provider for the database instance (singleton).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the PromptProfileDao.
final promptProfileDaoProvider = Provider<PromptProfileDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.promptProfileDao;
});

/// Provider for the processing service.
final processingServiceProvider = Provider<ProcessingServiceImpl>((ref) {
  final claudeService = ref.watch(claudeServiceProvider);
  final profileDao = ref.watch(promptProfileDaoProvider);
  final settingsService = ref.watch(settingsServiceProvider);
  final service = ProcessingServiceImpl(claudeService, profileDao, settingsService);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for reactive processing state updates.
final processingStateProvider = StreamProvider<ProcessingState>((ref) {
  final service = ref.watch(processingServiceProvider);
  return service.stateStream;
});
