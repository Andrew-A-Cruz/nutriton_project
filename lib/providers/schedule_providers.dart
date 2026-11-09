import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/schedule_repository.dart';
import 'infrastructure_providers.dart';

export '../data/repositories/schedule_repository.dart'
    show PendingScheduledMeal;

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(databaseProvider)),
);

/// Scheduled meals waiting for confirmation on one day ('yyyy-MM-dd'). Re-emits
/// on every write.
final pendingScheduledProvider =
    StreamProvider.family<List<PendingScheduledMeal>, String>(
      (ref, date) =>
          ref.watch(scheduleRepositoryProvider).watchPendingForDate(date),
    );

/// Every plan with its meal or food, for the Planned meals screen.
final allPlansProvider = StreamProvider<List<PendingScheduledMeal>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchPlans(),
);
