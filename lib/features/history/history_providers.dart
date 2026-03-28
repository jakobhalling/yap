import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/database/database.dart';
import '../../services/database/daos/history_dao.dart';
import '../processing/processing_providers.dart';
import '../settings/settings_providers.dart';
import 'history_service.dart';

/// Provider for the HistoryDao.
final historyDaoProvider = Provider<HistoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.historyDao;
});

/// Provider for the HistoryService.
final historyServiceProvider = Provider<HistoryService>((ref) {
  final dao = ref.watch(historyDaoProvider);
  final settings = ref.watch(settingsServiceProvider);
  return HistoryServiceImpl(dao, settings);
});

/// Stream provider for reactive history list updates.
final historyEntriesProvider = StreamProvider<List<HistoryData>>((ref) {
  final service = ref.watch(historyServiceProvider);
  return service.watchEntries();
});
