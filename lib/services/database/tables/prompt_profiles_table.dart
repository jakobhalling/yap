import 'package:drift/drift.dart';

/// Stores up to 4 prompt profiles (slots 1-4).
class PromptProfiles extends Table {
  IntColumn get slot => integer()(); // 1-4
  TextColumn get name => text()();
  TextColumn get systemPrompt => text()();
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {slot};
}
