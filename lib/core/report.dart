/// The shareable report (Pro): what a date range's PDF says, worked out
/// without any rendering so it can be tested directly. Pure Dart.
///
/// Averages follow the Summary rule: per logged day, so days with nothing
/// logged do not pull them down.
library;

import 'body_weight.dart';
import 'date_key.dart';
import 'metrics.dart';
import 'nutrition_math.dart';
import 'summary_math.dart';

/// One metric's line in the report's averages table.
class ReportMetricRow {
  const ReportMetricRow({
    required this.metric,
    required this.average,
    this.goal,
    this.daysOnTarget,
  });

  final Metric metric;

  /// Average per logged day. Null when nothing was logged, or when an
  /// optional metric was never recorded.
  final double? average;

  /// The daily goal, or null when the metric has none.
  final double? goal;

  /// Logged days within [goalTolerance] of the goal. Null without a goal.
  final int? daysOnTarget;

  /// The average as a whole percentage of the goal, or null.
  int? get percentOfGoal {
    final avg = average;
    final g = goal;
    if (avg == null || g == null || g <= 0) return null;
    return (avg / g * 100).round();
  }
}

/// Body weight over the report's range.
class ReportWeight {
  const ReportWeight({
    required this.first,
    required this.last,
    required this.count,
  });

  /// The earliest and latest weigh-ins inside the range.
  final WeightReading first;
  final WeightReading last;

  /// Weigh-ins inside the range.
  final int count;

  /// Latest minus earliest, in kilograms.
  double get changeKg => last.kg - first.kg;
}

/// Everything the PDF shows.
class ShareableReport {
  const ShareableReport({
    required this.startKey,
    required this.endKey,
    required this.totalDays,
    required this.metrics,
    required this.rows,
    required this.days,
    this.weight,
  });

  final String startKey;
  final String endKey;

  /// Calendar days in the range.
  final int totalDays;

  /// The metrics shown, primary first.
  final List<Metric> metrics;

  /// One row per metric in [metrics].
  final List<ReportMetricRow> rows;

  /// Each logged day in the range, oldest first, with its totals.
  final List<({String date, Macros totals})> days;

  /// Null when there was no weigh-in in the range.
  final ReportWeight? weight;

  int get daysLogged => days.length;
}

/// Builds the report for [startKey]..[endKey] (inclusive). [days] holds the
/// totals of logged days and [weights] the weigh-ins, oldest first; anything
/// outside the range is ignored. [goals] may lack a metric, which then has no
/// goal columns. With weekday goals, [goals] holds the range's average and
/// [goalOn] each day's goal, which days on target are counted against.
ShareableReport buildReport({
  required String startKey,
  required String endKey,
  required Map<String, Macros> days,
  required List<Metric> metrics,
  required Map<Metric, double> goals,
  required List<WeightReading> weights,
  double? Function(Metric metric, String day)? goalOn,
}) {
  bool inRange(String key) =>
      key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;

  final logged = [
    for (final e in days.entries)
      if (inRange(e.key)) (date: e.key, totals: e.value),
  ]..sort((a, b) => a.date.compareTo(b.date));
  final averages = averageOverLoggedDays([for (final d in logged) d.totals]);

  final rows = [
    for (final m in metrics)
      () {
        final goal = goals[m];
        final hasGoal = goal != null && goal > 0;
        return ReportMetricRow(
          metric: m,
          average: averages == null ? null : m.recordedAmountIn(averages),
          goal: hasGoal ? goal : null,
          daysOnTarget: !hasGoal
              ? null
              : goalOn == null
              ? daysOnTarget([for (final d in logged) d.totals], m, goal)
              : daysOnTargetEach(
                  {for (final d in logged) d.date: d.totals},
                  m,
                  (day) => goalOn(m, day),
                ),
        );
      }(),
  ];

  final weighed = [
    for (final w in weights)
      if (inRange(w.date)) w,
  ]..sort((a, b) => a.date.compareTo(b.date));

  return ShareableReport(
    startKey: startKey,
    endKey: endKey,
    totalDays: _daysInclusive(startKey, endKey),
    metrics: metrics,
    rows: rows,
    days: logged,
    weight: weighed.isEmpty
        ? null
        : ReportWeight(
            first: weighed.first,
            last: weighed.last,
            count: weighed.length,
          ),
  );
}

/// The suggested file name, e.g. `logbite-report-2026-10-10-to-2026-11-08.pdf`.
String reportFileName(String startKey, String endKey) => startKey == endKey
    ? 'logbite-report-$startKey.pdf'
    : 'logbite-report-$startKey-to-$endKey.pdf';

int _daysInclusive(String start, String end) {
  var n = 1;
  for (var k = start; k.compareTo(end) < 0; k = addDays(k, 1)) {
    n++;
  }
  return n;
}
