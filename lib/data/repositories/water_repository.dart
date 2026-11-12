import '../../core/water.dart';
import '../database/app_database.dart';

/// Water drunk per day, always in millilitres.
class WaterRepository {
  WaterRepository(this._db);

  final AppDatabase _db;

  /// Adds [deltaMl] to the total of [logDate] (negative takes away) and
  /// returns the new total. The total stays between 0 and [maxWaterMl], and a
  /// day back at 0 loses its row.
  Future<double> add(String logDate, double deltaMl) {
    if (!deltaMl.isFinite) {
      throw ArgumentError.value(deltaMl, 'deltaMl', 'must be finite');
    }
    return _db.transaction(() async {
      final current = (await _db.waterDao.forDate(logDate))?.amountMl ?? 0;
      final next = adjustWater(current, deltaMl);
      if (next <= 0) {
        await _db.waterDao.deleteForDate(logDate);
      } else {
        await _db.waterDao.upsertForDate(logDate, next);
      }
      return next;
    });
  }

  /// The total for [logDate] in millilitres, 0 when none. Re-emits on every
  /// write.
  Stream<double> watchAmount(String logDate) =>
      _db.waterDao.watchForDate(logDate).map((r) => r?.amountMl ?? 0);

  /// The totals of the days with water from [startDate] to [endDate]
  /// inclusive, oldest first.
  Stream<List<double>> watchRange(String startDate, String endDate) => _db
      .waterDao
      .watchRange(startDate, endDate)
      .map((rows) => [for (final r in rows) r.amountMl]);
}
