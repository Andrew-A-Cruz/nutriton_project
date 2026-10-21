/// Summary View arithmetic: which days a range covers, how days are grouped
/// into bars, and the averages over logged days. Pure Dart, so it has no
/// Flutter or drift imports and is unit-tested directly.
///
/// Averaging rule: day totals are taken first, then averaged over the days
/// that have at least one entry. Days with nothing logged are skipped, so they
/// do not pull averages down.
library;

import 'date_key.dart';
import 'nutrition_math.dart';

/// The Summary View ranges. [days] counts the end day, so a week ending today
/// starts six days back.
enum SummaryRange {
  day(1, 'Day', BucketSize.day),
  week(7, 'Week', BucketSize.day),
  month(30, 'Month', BucketSize.day),
  sixMonths(180, '6M', BucketSize.week),
  year(365, 'Year', BucketSize.month);

  const SummaryRange(this.days, this.label, this.bucketSize);

  final int days;
  final String label;

  /// How days are grouped into bars. Short ranges plot each day; long ranges
  /// plot averages per week or per calendar month so the bars stay readable.
  final BucketSize bucketSize;
}

/// How days are grouped into bars.
enum BucketSize { day, week, month }

/// Totals for one day that has at least one entry.
class DayTotal {
  const DayTotal({required this.logDate, required this.totals});

  /// 'yyyy-MM-dd'.
  final String logDate;
  final Macros totals;
}

/// One bar: the days from [startKey] to [endKey] inclusive.
class Bucket {
  const Bucket({
    required this.startKey,
    required this.endKey,
    required this.dayCount,
    required this.daysLogged,
    required this.averages,
  });

  final String startKey;
  final String endKey;

  /// Calendar days in the span, logged or not.
  final int dayCount;

  /// Days in the span with at least one entry.
  final int daysLogged;

  /// Average per logged day. Null when no day in the span was logged.
  final Macros? averages;
}

/// Everything the Summary View shows for one range ending on one day.
class SummaryReport {
  const SummaryReport({
    required this.range,
    required this.startKey,
    required this.endKey,
    required this.daysLogged,
    required this.averages,
    required this.buckets,
  });

  final SummaryRange range;
  final String startKey;
  final String endKey;

  /// Calendar days in the range (the "N" of "n of N").
  int get totalDays => range.days;

  /// Days in the range with at least one entry (the "n" of "n of N").
  final int daysLogged;

  /// Average per logged day across the whole range. Null when nothing is
  /// logged.
  final Macros? averages;

  /// Bars for the chart, oldest first. Empty for [SummaryRange.day].
  final List<Bucket> buckets;
}

/// The first day of a window of [days] days ending on [endKey], inclusive.
/// A 7-day window ending on 2026-10-20 starts on 2026-10-14.
String windowStart(String endKey, int days) {
  if (days < 1) {
    throw ArgumentError.value(days, 'days', 'must be >= 1');
  }
  return addDays(endKey, -(days - 1));
}

/// Builds the report for [range] ending on [endKey]. [days] may include
/// entries outside the window; they are ignored, and days with several
/// entries are summed.
SummaryReport buildSummaryReport({
  required String endKey,
  required SummaryRange range,
  required Iterable<DayTotal> days,
}) {
  final start = windowStart(endKey, range.days);
  final byDay = <String, Macros>{};
  for (final day in days) {
    if (day.logDate.compareTo(start) < 0 || day.logDate.compareTo(endKey) > 0) {
      continue;
    }
    byDay[day.logDate] = (byDay[day.logDate] ?? Macros.zero) + day.totals;
  }

  // A one-day range has no trend to chart, so it gets no bars.
  final buckets = range == SummaryRange.day
      ? const <Bucket>[]
      : [
          for (final (s, e) in bucketSpans(
            start: start,
            end: endKey,
            size: range.bucketSize,
          ))
            _bucketFor(s, e, byDay),
        ];

  return SummaryReport(
    range: range,
    startKey: start,
    endKey: endKey,
    daysLogged: byDay.length,
    averages: averageOverLoggedDays(byDay.values),
    buckets: buckets,
  );
}

/// Mean of [days], one value per logged day. Null when there are none.
Macros? averageOverLoggedDays(Iterable<Macros> days) {
  var count = 0;
  var total = Macros.zero;
  for (final day in days) {
    total += day;
    count++;
  }
  if (count == 0) return null;
  return Macros(
    calories: total.calories / count,
    protein: total.protein / count,
    carbs: total.carbs / count,
    fat: total.fat / count,
  );
}

/// Splits [start]..[end] (inclusive 'yyyy-MM-dd' keys) into consecutive spans.
///
/// - [BucketSize.day]: one span per day.
/// - [BucketSize.week]: 7-day spans counted back from [end], so the newest
///   week is always complete. The oldest span may be shorter.
/// - [BucketSize.month]: calendar months, clipped to the range at both ends.
List<(String, String)> bucketSpans({
  required String start,
  required String end,
  required BucketSize size,
}) {
  if (start.compareTo(end) > 0) {
    throw ArgumentError('start $start is after end $end');
  }
  switch (size) {
    case BucketSize.day:
      return [
        for (var k = start; k.compareTo(end) <= 0; k = addDays(k, 1)) (k, k),
      ];
    case BucketSize.week:
      final spans = <(String, String)>[];
      var spanEnd = end;
      while (spanEnd.compareTo(start) >= 0) {
        final spanStart = _maxKey(addDays(spanEnd, -6), start);
        spans.add((spanStart, spanEnd));
        spanEnd = addDays(spanStart, -1);
      }
      return spans.reversed.toList();
    case BucketSize.month:
      final spans = <(String, String)>[];
      var cursor = start;
      while (cursor.compareTo(end) <= 0) {
        final spanEnd = _minKey(_endOfMonth(cursor), end);
        spans.add((cursor, spanEnd));
        cursor = addDays(spanEnd, 1);
      }
      return spans;
  }
}

Bucket _bucketFor(String start, String end, Map<String, Macros> byDay) {
  final dayCount = _daysBetween(start, end) + 1;
  final logged = <Macros>[];
  var key = start;
  for (var i = 0; i < dayCount; i++) {
    final totals = byDay[key];
    if (totals != null) logged.add(totals);
    key = addDays(key, 1);
  }
  return Bucket(
    startKey: start,
    endKey: end,
    dayCount: dayCount,
    daysLogged: logged.length,
    averages: averageOverLoggedDays(logged),
  );
}

String _minKey(String a, String b) => a.compareTo(b) <= 0 ? a : b;

String _maxKey(String a, String b) => a.compareTo(b) >= 0 ? a : b;

/// The last day of the calendar month containing [key].
String _endOfMonth(String key) {
  final d = dateFromKey(key);
  // Day 0 of the next month is the last day of this one.
  return dateKey(DateTime(d.year, d.month + 1, 0));
}

/// Whole calendar days from [start] to [end]. UTC avoids daylight-saving
/// offsets.
int _daysBetween(String start, String end) {
  DateTime utc(String key) {
    final d = dateFromKey(key);
    return DateTime.utc(d.year, d.month, d.day);
  }

  return utc(end).difference(utc(start)).inDays;
}
