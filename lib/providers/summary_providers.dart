import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/summary_math.dart';
import 'infrastructure_providers.dart';

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

/// Arguments for [summaryReportProvider]: a range ending on a 'yyyy-MM-dd' day.
typedef SummaryQuery = ({String endDate, SummaryRange range});

/// The report for one range. Re-emits on every log change.
final summaryReportProvider =
    StreamProvider.family<SummaryReport, SummaryQuery>(
      (ref, query) => ref
          .watch(summaryRepositoryProvider)
          .watchReport(endDate: query.endDate, range: query.range),
    );
