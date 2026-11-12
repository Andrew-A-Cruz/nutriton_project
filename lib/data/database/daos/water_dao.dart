import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/water_log.dart';

part 'water_dao.g.dart';

@DriftAccessor(tables: [WaterLog])
class WaterDao extends DatabaseAccessor<AppDatabase> with _$WaterDaoMixin {
  WaterDao(super.attachedDatabase);

  Future<WaterDay?> forDate(String logDate) => (select(
    waterLog,
  )..where((t) => t.logDate.equals(logDate))).getSingleOrNull();

  /// Sets the day's total, replacing any earlier one.
  Future<void> upsertForDate(String logDate, double amountMl) => into(
    waterLog,
  ).insertOnConflictUpdate(WaterDay(logDate: logDate, amountMl: amountMl));

  Future<int> deleteForDate(String logDate) =>
      (delete(waterLog)..where((t) => t.logDate.equals(logDate))).go();

  /// The day's row, or null. Re-emits on every change.
  Stream<WaterDay?> watchForDate(String logDate) => (select(
    waterLog,
  )..where((t) => t.logDate.equals(logDate))).watchSingleOrNull();

  /// Days from [startDate] to [endDate] inclusive, oldest first.
  Stream<List<WaterDay>> watchRange(String startDate, String endDate) =>
      (select(waterLog)
            ..where((t) => t.logDate.isBetweenValues(startDate, endDate))
            ..orderBy([(t) => OrderingTerm.asc(t.logDate)]))
          .watch();
}
