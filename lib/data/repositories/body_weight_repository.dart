import '../../core/body_weight.dart';
import '../database/app_database.dart';

/// Body weight readings, one per day, always in kilograms.
class BodyWeightRepository {
  BodyWeightRepository(this._db);

  final AppDatabase _db;

  /// Sets the reading for [logDate], replacing any earlier one. Throws
  /// [ArgumentError] when [kg] is outside the accepted range.
  Future<void> setWeight(String logDate, double kg) {
    if (!kg.isFinite || kg < minBodyWeightKg || kg > maxBodyWeightKg) {
      throw ArgumentError.value(kg, 'kg', 'outside the accepted range');
    }
    return _db.bodyWeightDao.upsertForDate(logDate, kg, DateTime.now());
  }

  /// Stores weights read from the health store; see
  /// [BodyWeightDao.importHealthReadings]. Safe to repeat.
  Future<int> importHealthReadings(List<WeightReading> readings) =>
      _db.bodyWeightDao.importHealthReadings(readings, DateTime.now());

  Future<void> clearWeight(String logDate) =>
      _db.bodyWeightDao.deleteForDate(logDate);

  /// The reading for [logDate] in kilograms, or null. Re-emits on every write.
  Stream<double?> watchWeight(String logDate) =>
      _db.bodyWeightDao.watchForDate(logDate).map((r) => r?.weightKg);

  /// Where the reading for [logDate] came from, or null when there is none.
  Stream<WeightSource?> watchSource(String logDate) => _db.bodyWeightDao
      .watchForDate(logDate)
      .map((r) => r == null ? null : WeightSource.fromDb(r.source));

  /// Readings from [startDate] to [endDate] inclusive, oldest first.
  Stream<List<WeightReading>> watchRange(String startDate, String endDate) =>
      _db.bodyWeightDao
          .watchRange(startDate, endDate)
          .map(
            (rows) => [for (final r in rows) (date: r.logDate, kg: r.weightKg)],
          );
}
