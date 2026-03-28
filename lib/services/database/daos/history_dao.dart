import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/history_table.dart';

part 'history_dao.g.dart';

@DriftAccessor(tables: [History])
class HistoryDao extends DatabaseAccessor<AppDatabase>
    with _$HistoryDaoMixin {
  HistoryDao(super.db);

  /// Insert a new history entry. Returns the auto-generated ID.
  Future<int> insertEntry(HistoryCompanion entry) {
    return into(history).insert(entry);
  }

  /// Get all entries, newest first, with optional pagination.
  Future<List<HistoryData>> getAllEntries({
    int limit = 50,
    int offset = 0,
  }) {
    return (select(history)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Get a single entry by ID.
  Future<HistoryData?> getEntry(int id) {
    return (select(history)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Delete a single entry by ID.
  Future<void> deleteEntry(int id) {
    return (delete(history)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all history entries.
  Future<void> clearAll() {
    return delete(history).go();
  }

  /// Watch all entries for reactive UI updates. Newest first.
  Stream<List<HistoryData>> watchAllEntries() {
    return (select(history)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
