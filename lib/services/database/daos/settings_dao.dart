import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/settings_table.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Get the value for a settings key, or null if not set.
  Future<String?> get(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Set a settings key-value pair. Inserts or updates.
  Future<void> set(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  /// Delete a settings key.
  Future<void> deleteKey(String key) {
    return (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  /// Watch a single key for reactive updates.
  Stream<String?> watchKey(String key) {
    return (select(settings)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }
}
