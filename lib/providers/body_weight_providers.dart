import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/body_weight.dart';
import '../core/date_key.dart';
import '../core/summary_math.dart';
import '../data/repositories/body_weight_repository.dart';
import 'infrastructure_providers.dart';
import 'today_providers.dart';

final bodyWeightRepositoryProvider = Provider<BodyWeightRepository>(
  (ref) => BodyWeightRepository(ref.watch(databaseProvider)),
);

/// The weight in kilograms logged on one day ('yyyy-MM-dd'), or null. Re-emits
/// on every write.
final bodyWeightForDateProvider = StreamProvider.family<double?, String>(
  (ref, date) => ref.watch(bodyWeightRepositoryProvider).watchWeight(date),
);

/// Where the weight logged on one day came from, or null when there is none.
final bodyWeightSourceForDateProvider =
    StreamProvider.family<WeightSource?, String>(
      (ref, date) => ref.watch(bodyWeightRepositoryProvider).watchSource(date),
    );

/// Readings for a Summary range ending today, oldest first. They start
/// [movingAverageDays] - 1 days before the range, so the moving average on the
/// first day shown already has its full window.
final bodyWeightRangeProvider =
    StreamProvider.family<List<WeightReading>, SummaryRange>((ref, range) {
      final end = ref.watch(todayProvider);
      final start = addDays(
        windowStart(end, range.days),
        -(movingAverageDays - 1),
      );
      return ref.watch(bodyWeightRepositoryProvider).watchRange(start, end);
    });
