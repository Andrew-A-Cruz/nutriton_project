import '../../core/streak.dart';
import '../../core/summary_math.dart';
import '../database/app_database.dart';

/// Builds Summary View reports from the log. The grouping and averaging rules
/// live in `core/summary_math.dart`; this class only fetches the day totals.
class SummaryRepository {
  SummaryRepository(this._db);

  final AppDatabase _db;

  /// The current logging streak as of [today] ('yyyy-MM-dd'), re-emitting
  /// whenever the log changes. See [currentStreak].
  Stream<int> watchStreak(String today) => _db.summaryDao
      .watchLoggedDatesUpTo(today)
      .map((dates) => currentStreak(dates, today: today));

  /// Totals for each day from [startDate] to [endDate] ('yyyy-MM-dd',
  /// inclusive) that has entries, oldest first. Re-emits whenever the log
  /// changes.
  Stream<List<DayTotal>> watchDailyTotals(String startDate, String endDate) =>
      _db.summaryDao.watchDailyTotalsForRange(startDate, endDate);

  /// The report for [range] ending on [endDate] ('yyyy-MM-dd', inclusive).
  /// Re-emits whenever the log changes.
  Stream<SummaryReport> watchReport({
    required String endDate,
    required SummaryRange range,
  }) {
    final start = windowStart(endDate, range.days);
    return _db.summaryDao
        .watchDailyTotalsForRange(start, endDate)
        .map(
          (days) =>
              buildSummaryReport(endKey: endDate, range: range, days: days),
        );
  }
}
