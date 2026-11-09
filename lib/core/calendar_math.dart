/// The calendar of logged days: the month grid and how each day is marked.
/// Pure Dart.
library;

import 'date_key.dart';
import 'nutrition_math.dart';
import 'metrics.dart';
import 'summary_math.dart';

/// The month containing [key] as ('yyyy', 'MM') numbers.
typedef Month = ({int year, int month});

Month monthOf(String key) {
  final d = dateFromKey(key);
  return (year: d.year, month: d.month);
}

/// The month [delta] months after [month] (negative for before).
Month addMonths(Month month, int delta) {
  final d = DateTime(month.year, month.month + delta);
  return (year: d.year, month: d.month);
}

/// First and last day keys of [month].
(String, String) monthSpan(Month month) => (
  dateKey(DateTime(month.year, month.month)),
  dateKey(DateTime(month.year, month.month + 1, 0)),
);

/// [month] as weeks of seven day keys, Sunday first. Days outside the month
/// are null, so the first and last weeks may be padded.
List<List<String?>> monthGrid(Month month) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  // DateTime.weekday: Monday 1 .. Sunday 7. Sunday-first offset is 0..6.
  final lead = first.weekday % 7;
  final cells = <String?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= daysInMonth; d++)
      dateKey(DateTime(month.year, month.month, d)),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
}

/// How a day shows in the calendar.
enum DayMark {
  /// Nothing logged.
  none,

  /// Logged, with no goal to compare against (or mindful mode).
  logged,
  under,
  onTarget,
  over,
}

/// The mark for a day whose totals are [totals] (null when nothing was
/// logged), against [goal] for [metric].
DayMark dayMark(Macros? totals, Metric metric, double? goal) {
  if (totals == null) return DayMark.none;
  if (goal == null || goal <= 0) return DayMark.logged;
  return switch (goalStatus(metric.amountIn(totals), goal)) {
    GoalStatus.under => DayMark.under,
    GoalStatus.onTarget => DayMark.onTarget,
    GoalStatus.over => DayMark.over,
  };
}
