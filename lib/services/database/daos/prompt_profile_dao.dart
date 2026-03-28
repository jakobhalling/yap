import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/prompt_profiles_table.dart';
import '../../../shared/prompts/default_prompts.dart';

part 'prompt_profile_dao.g.dart';

@DriftAccessor(tables: [PromptProfiles])
class PromptProfileDao extends DatabaseAccessor<AppDatabase>
    with _$PromptProfileDaoMixin {
  PromptProfileDao(super.db);

  /// Get a single profile by slot number (1-4).
  Future<PromptProfile?> getProfile(int slot) {
    return (select(promptProfiles)..where((t) => t.slot.equals(slot)))
        .getSingleOrNull();
  }

  /// Get all profiles ordered by slot.
  Future<List<PromptProfile>> getAllProfiles() {
    return (select(promptProfiles)
          ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
        .get();
  }

  /// Update a profile's name and/or system prompt. Marks it as non-default.
  Future<void> updateProfile(
    int slot, {
    String? name,
    String? systemPrompt,
  }) {
    return (update(promptProfiles)..where((t) => t.slot.equals(slot))).write(
      PromptProfilesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        systemPrompt:
            systemPrompt != null ? Value(systemPrompt) : const Value.absent(),
        isDefault: const Value(false),
      ),
    );
  }

  /// Reset a profile slot back to its default content.
  Future<void> resetToDefault(int slot) async {
    final defaultProfile = DefaultPrompts.defaults.firstWhere(
      (p) => p.slot == slot,
      orElse: () => PromptProfileData(slot: slot, name: '', systemPrompt: ''),
    );
    await (update(promptProfiles)..where((t) => t.slot.equals(slot))).write(
      PromptProfilesCompanion(
        name: Value(defaultProfile.name),
        systemPrompt: Value(defaultProfile.systemPrompt),
        isDefault: const Value(true),
      ),
    );
  }

  /// Watch all profiles for reactive UI updates.
  Stream<List<PromptProfile>> watchAllProfiles() {
    return (select(promptProfiles)
          ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
        .watch();
  }
}
