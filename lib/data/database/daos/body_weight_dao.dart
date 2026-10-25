import 'package:drift/drift.dart';

import '../../../core/body_weight.dart';
import '../app_database.dart';
import '../tables/body_weights.dart';

part 'body_weight_dao.g.dart';

@DriftAccessor(tables: [BodyWeights])
class BodyWeightDao extends DatabaseAccessor<AppDatabase>
    with _$BodyWeightDaoMixin {
  BodyWeightDao(super.attachedDatabase);

  /// Sets the reading for [logDate], replacing any earlier one. A reading set
  /// here is manual unless [source] says otherwise.
  Future<void> upsertForDate(
    String logDate,
    double weightKg,
    DateTime createdAt, {
    WeightSource source = WeightSource.manual,
  }) => into(bodyWeights).insertOnConflictUpdate(
    BodyWeightsCompanion.insert(
      logDate: logDate,
      weightKg: weightKg,
      createdAt: createdAt,
      source: Value(source.dbValue),
    ),
  );

  /// Stores [readings] from the health store: a day with no reading gets one,
  /// a day whose reading is itself from health is updated, and a manual
  /// reading is never touched. Returns how many days changed.
  Future<int> importHealthReadings(
    List<WeightReading> readings,
    DateTime now,
  ) => transaction(() async {
    var changed = 0;
    for (final r in readings) {
      final existing = await (select(
        bodyWeights,
      )..where((t) => t.logDate.equals(r.date))).getSingleOrNull();
      if (existing != null) {
        if (WeightSource.fromDb(existing.source) != WeightSource.health ||
            existing.weightKg == r.kg) {
          continue;
        }
      }
      await upsertForDate(r.date, r.kg, now, source: WeightSource.health);
      changed++;
    }
    return changed;
  });

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
