// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Fasts from the fasting timer. A row with no [endedAt] is the fast in
/// progress; the repository keeps at most one.
class Fasts extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();

  /// Null while the fast is running. Never before [startedAt].
  DateTimeColumn get endedAt => dateTime().nullable().check(
    endedAt.isNull() | endedAt.isBiggerOrEqual(startedAt),
  )();

  @override
  Set<Column> get primaryKey => {id};
}
