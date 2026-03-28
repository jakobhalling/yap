import 'package:drift/drift.dart';

/// Stores completed transcription/processing sessions.
class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get rawTranscript => text()();
  TextColumn get profileName => text().nullable()(); // NULL if raw paste
  TextColumn get profilePrompt => text().nullable()(); // Snapshot of prompt used
  TextColumn get processedText => text().nullable()(); // NULL if raw paste
  TextColumn get pastedText => text()(); // What was actually pasted
  RealColumn get durationSeconds => real().nullable()(); // Recording duration
}
