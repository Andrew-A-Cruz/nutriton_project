// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Body weight, at most one reading per day. Always stored in kilograms; the
/// `body_weight_unit` preference only changes how it is shown and typed.
class BodyWeights extends Table {
  /// Day of the reading, 'yyyy-MM-dd'. One row per day, so it is the key.
  TextColumn get logDate => text()();
  RealColumn get weightKg => real().check(weightKg.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();

  /// Where the reading came from: 'manual' (typed in the app) or 'health'
  /// (read from Apple Health). Null, from an old backup, counts as manual.
  TextColumn get source =>
      text().nullable().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {logDate};
}
