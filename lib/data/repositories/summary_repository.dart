import '../../core/summary_math.dart';
import '../database/app_database.dart';

/// Builds Summary View reports from the log. The grouping and averaging rules
/// live in `core/summary_math.dart`; this class only fetches the day totals.
class SummaryRepository {
  SummaryRepository(this._db);

  final AppDatabase _db;

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
