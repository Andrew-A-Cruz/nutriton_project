import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_key.dart';
import '../core/health.dart';
import '../core/nutrition_math.dart';
import '../data/health/health_service.dart';
import '../data/health/health_sync.dart';
import 'body_weight_providers.dart';
import 'entitlement_providers.dart';
import 'infrastructure_providers.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

/// The health store. A no-op until `main` overrides it with the real one, so
/// tests and unsupported platforms never touch the plugin.
final healthServiceProvider = Provider<HealthService>(
  (ref) => const NoopHealthService(),
);

/// Whether this platform has a health store to offer. Settings shows the
/// Apple Health section only when true; `main` sets it on iOS.
final healthSupportedProvider = Provider<bool>((ref) => false);

final healthSyncProvider = Provider<HealthSync>(
  (ref) => HealthSync(
    ref.watch(healthServiceProvider),
    ref.watch(bodyWeightRepositoryProvider),
  ),
);

/// Daily totals for the days [healthBackfillDays] back from [today], for the
/// days that have entries. Re-emits on every log change.
final healthWindowTotalsProvider =
    StreamProvider.family<Map<String, Macros>, String>(
      (ref, today) => ref
          .watch(summaryRepositoryProvider)
          .watchDailyTotals(addDays(today, 1 - healthBackfillDays), today)
          .map((days) => {for (final d in days) d.logDate: d.totals}),
    );

/// Keeps the nutrition written to Apple Health in line with the log while the
/// switch in Settings is on. Watched from the root, so it runs at launch, when
/// the switch is turned on (backfilling the window), and whenever an entry is
/// added, edited or deleted. Does nothing, and makes no calls, while off or
/// without Pro. What was already written stays in Health.
final healthNutritionPlanProvider = Provider<void>((ref) {
  final enabled =
      ref.watch(preferencesProvider.select((s) => s.healthWriteNutrition)) &&
      ref.watch(proProvider);
  final today = ref.watch(todayProvider);
  final sync = ref.read(healthSyncProvider);
  if (!enabled) {
    unawaited(
      sync
          .syncNutrition(enabled: false, today: today, totals: const {})
          .catchError((Object _) {}),
    );
    return;
  }
  // Wait for the log to load: syncing early would look like an empty log.
  final totals = ref.watch(healthWindowTotalsProvider(today)).value;
  if (totals == null) return;
  // A health failure (say, access revoked in Settings) must not crash the app.
  unawaited(
    sync
        .syncNutrition(enabled: true, today: today, totals: totals)
        .catchError((Object _) {}),
  );
});

/// Reads body weight from Apple Health while the switch in Settings is on:
/// at launch, when it is turned on, and when the day rolls over. Not without
/// Pro; weights already read in stay.
final healthWeightPlanProvider = Provider<void>((ref) {
  final enabled =
      ref.watch(preferencesProvider.select((s) => s.healthReadWeight)) &&
      ref.watch(proProvider);
  final today = ref.watch(todayProvider);
  unawaited(
    ref
        .read(healthSyncProvider)
        .importWeights(enabled: enabled, today: today)
        .catchError((Object _) {}),
  );
});

/// Whether Today shows the step count. Device-local (see
/// `UserPreferences.readShowSteps`).
class ShowStepsNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(userPreferencesProvider).readShowSteps();

  Future<void> set(bool on) async {
    state = on;
    await ref.read(userPreferencesProvider).writeShowSteps(on);
  }
}

final showStepsProvider = NotifierProvider<ShowStepsNotifier, bool>(
  ShowStepsNotifier.new,
);

/// The daily step goal, or null for none. Device-local.
class StepsGoalNotifier extends Notifier<int?> {
  @override
  int? build() => ref.watch(userPreferencesProvider).readStepsGoal();

  Future<void> set(int? goal) async {
    state = goal == null || goal <= 0 ? null : goal;
    await ref.read(userPreferencesProvider).writeStepsGoal(state);
  }
}

final stepsGoalProvider = NotifierProvider<StepsGoalNotifier, int?>(
  StepsGoalNotifier.new,
);

/// Whether steps are read and shown: the switch is on, with Pro, where a
/// health store exists. The switch stays as it was when Pro lapses, so
/// steps come back with Pro.
final stepsEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(healthSupportedProvider) &&
      ref.watch(showStepsProvider) &&
      ref.watch(proProvider),
);

/// Counts up each time the app returns to the foreground, so steps walked
/// meanwhile show without a restart.
class StepsRefreshNotifier extends Notifier<int> {
  @override
  int build() {
    ref.keepAlive();
    final lifecycle = AppLifecycleListener(onResume: () => state++);
    ref.onDispose(lifecycle.dispose);
    return 0;
  }
}

final stepsRefreshProvider = NotifierProvider<StepsRefreshNotifier, int>(
  StepsRefreshNotifier.new,
);

/// A range of days, both 'yyyy-MM-dd' and inclusive.
typedef StepsRange = ({String start, String end});

/// Steps per day in a range, read live from the health store and never
/// stored. Empty while steps are off. Read again when the app returns to the
/// foreground.
final dailyStepsProvider = FutureProvider.family<Map<String, int>, StepsRange>((
  ref,
  range,
) async {
  if (!ref.watch(stepsEnabledProvider)) return const {};
  ref.watch(stepsRefreshProvider);
  return ref
      .watch(healthServiceProvider)
      .readDailySteps(range.start, range.end);
});
