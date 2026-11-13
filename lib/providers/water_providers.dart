import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/summary_math.dart';
import '../data/repositories/water_repository.dart';
import 'infrastructure_providers.dart';
import 'summary_providers.dart';

final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => WaterRepository(ref.watch(databaseProvider)),
);

/// Milliliters of water on one day ('yyyy-MM-dd'), 0 when none. Re-emits on
/// every write.
final waterForDateProvider = StreamProvider.family<double, String>(
  (ref, date) => ref.watch(waterRepositoryProvider).watchAmount(date),
);

/// The totals of the days with water in a Summary range, oldest first.
final waterRangeProvider = StreamProvider.family<List<double>, SummaryQuery>((
  ref,
  query,
) {
  final end = query.endDate;
  return ref
      .watch(waterRepositoryProvider)
      .watchRange(windowStart(end, query.range.days), end);
});
