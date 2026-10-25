import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/body_weights.dart';

part 'body_weight_dao.g.dart';

@DriftAccessor(tables: [BodyWeights])
class BodyWeightDao extends DatabaseAccessor<AppDatabase>
    with _$BodyWeightDaoMixin {
  BodyWeightDao(super.attachedDatabase);

  /// Sets the reading for [logDate], replacing any earlier one.
  Future<void> upsertForDate(
    String logDate,
    double weightKg,
    DateTime createdAt,
  ) => into(bodyWeights).insertOnConflictUpdate(
    BodyWeightsCompanion.insert(
      logDate: logDate,
      weightKg: weightKg,
      createdAt: createdAt,
    ),
  );

  Future<int> deleteForDate(String logDate) =>
      (delete(bodyWeights)..where((t) => t.logDate.equals(logDate))).go();

  /// The reading for [logDate], or null. Re-emits on every change.
  Stream<BodyWeight?> watchForDate(String logDate) => (select(
    bodyWeights,
  )..where((t) => t.logDate.equals(logDate))).watchSingleOrNull();

  /// Readings from [startDate] to [endDate] inclusive, oldest first.
  Stream<List<BodyWeight>> watchRange(String startDate, String endDate) =>
      (select(bodyWeights)
            ..where((t) => t.logDate.isBetweenValues(startDate, endDate))
            ..orderBy([(t) => OrderingTerm.asc(t.logDate)]))
          .watch();
}
