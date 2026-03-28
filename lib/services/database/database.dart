import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/history_table.dart';
import 'tables/prompt_profiles_table.dart';
import 'tables/settings_table.dart';
import 'daos/history_dao.dart';
import 'daos/prompt_profile_dao.dart';
import 'daos/settings_dao.dart';
import '../../shared/prompts/default_prompts.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [History, PromptProfiles, Settings],
  daos: [HistoryDao, PromptProfileDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor — uses file-based storage in the app data directory.
  AppDatabase() : super(_openConnection());

  /// Constructor for testing — accepts any QueryExecutor (e.g. in-memory).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultProfiles();
        },
      );

  /// Seed the 4 default prompt profiles into the database.
  Future<void> _seedDefaultProfiles() async {
    for (final profile in DefaultPrompts.defaults) {
      await into(promptProfiles).insert(
        PromptProfilesCompanion(
          slot: Value(profile.slot),
          name: Value(profile.name),
          systemPrompt: Value(profile.systemPrompt),
          isDefault: const Value(true),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbFolder = Directory(p.join(dir.path, 'yap'));
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
    final file = File(p.join(dbFolder.path, 'yap.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
