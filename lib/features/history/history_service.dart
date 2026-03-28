import 'package:drift/drift.dart';
import '../../services/database/daos/history_dao.dart';
import '../../services/database/database.dart';
import '../settings/settings_service.dart';

/// Abstract interface for history management.
abstract class HistoryService {
  /// Save a completed session to history.
  Future<void> saveEntry({
    required String rawTranscript,
    String? profileName,
    String? profilePrompt,
    String? processedText,
    required String pastedText,
    double? durationSeconds,
  });

  /// Get all history entries, newest first.
  Future<List<HistoryData>> getEntries({int limit = 50, int offset = 0});

  /// Watch entries for reactive UI updates.
  Stream<List<HistoryData>> watchEntries();

  /// Get a single entry by ID.
  Future<HistoryData?> getEntry(int id);

  /// Delete a single entry.
  Future<void> deleteEntry(int id);

  /// Clear all history.
  Future<void> clearAll();

  /// Check if history recording is enabled.
  Future<bool> isEnabled();
}

/// Production implementation backed by the history DAO.
class HistoryServiceImpl implements HistoryService {
  final HistoryDao _dao;
  final SettingsService _settings;

  HistoryServiceImpl(this._dao, this._settings);

  @override
  Future<void> saveEntry({
    required String rawTranscript,
    String? profileName,
    String? profilePrompt,
    String? processedText,
    required String pastedText,
    double? durationSeconds,
  }) async {
    // Check if history is enabled before saving.
    final enabled = await isEnabled();
    if (!enabled) return;

    await _dao.insertEntry(HistoryCompanion(
      rawTranscript: Value(rawTranscript),
      profileName: Value(profileName),
      profilePrompt: Value(profilePrompt),
      processedText: Value(processedText),
      pastedText: Value(pastedText),
      durationSeconds: Value(durationSeconds),
    ));
  }

  @override
  Future<List<HistoryData>> getEntries({
    int limit = 50,
    int offset = 0,
  }) {
    return _dao.getAllEntries(limit: limit, offset: offset);
  }

  @override
  Stream<List<HistoryData>> watchEntries() {
    return _dao.watchAllEntries();
  }

  @override
  Future<HistoryData?> getEntry(int id) {
    return _dao.getEntry(id);
  }

  @override
  Future<void> deleteEntry(int id) {
    return _dao.deleteEntry(id);
  }

  @override
  Future<void> clearAll() {
    return _dao.clearAll();
  }

  @override
  Future<bool> isEnabled() {
    return _settings.getHistoryEnabled();
  }
}
