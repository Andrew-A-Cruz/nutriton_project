import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar_math.dart';
import '../core/nutrition_math.dart';
import '../core/summary_math.dart';
import 'infrastructure_providers.dart';
import 'today_providers.dart';

/// The range chosen on the Summary segmented control. Kept alive so it
/// survives switching tabs.
class SummaryRangeNotifier extends Notifier<SummaryRange> {
  @override
  SummaryRange build() {
    ref.keepAlive();
    return SummaryRange.week;
  }

  void select(SummaryRange range) => state = range;
}

final summaryRangeProvider =
    NotifierProvider<SummaryRangeNotifier, SummaryRange>(
      SummaryRangeNotifier.new,
    );

/// The last day Summary shows. Null follows today (also across midnight); the
/// arrows set a day in the past. Kept alive so it survives switching tabs.
class SummaryEndNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.keepAlive();
    return null;
  }

  /// Moves back (-1) or forward (+1) by one [range]. Reaching today goes back
  /// to following it.
  void step(SummaryRange range, int direction) {
    final today = ref.read(todayProvider);
    final next = stepSummaryEnd(state ?? today, range, direction, today: today);
    state = next == today ? null : next;
  }

  void showToday() => state = null;
}

final summaryEndNotifierProvider =
    NotifierProvider<SummaryEndNotifier, String?>(SummaryEndNotifier.new);

/// The day Summary ends on: the chosen day, or today.
final summaryEndProvider = Provider<String>((ref) {
  final today = ref.watch(todayProvider);
  final chosen = ref.watch(summaryEndNotifierProvider);
  return chosen == null || chosen.compareTo(today) > 0 ? today : chosen;
});

/// Arguments for [summaryReportProvider]: a range ending on a 'yyyy-MM-dd' day.
typedef SummaryQuery = ({String endDate, SummaryRange range});

/// The report for one range. Re-emits on every log change.
final summaryReportProvider =
    StreamProvider.family<SummaryReport, SummaryQuery>(
      (ref, query) => ref
          .watch(summaryRepositoryProvider)
          .watchReport(endDate: query.endDate, range: query.range),
    );

/// The current logging streak. Moves to the new day at midnight.
final streakProvider = StreamProvider<int>(
  (ref) => ref
      .watch(summaryRepositoryProvider)
      .watchStreak(ref.watch(todayProvider)),
);

/// Totals for each logged day of one month, by day key. Re-emits on every
/// log change. Feeds the calendar.
final monthTotalsProvider = StreamProvider.family<Map<String, Macros>, Month>((
  ref,
  month,
) {
  final (start, end) = monthSpan(month);
  return ref
      .watch(summaryRepositoryProvider)
      .watchDailyTotals(start, end)
      .map((days) => {for (final d in days) d.logDate: d.totals});
});
