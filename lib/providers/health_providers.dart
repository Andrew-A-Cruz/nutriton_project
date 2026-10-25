import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_key.dart';
import '../core/health.dart';
import '../core/nutrition_math.dart';
import '../data/health/health_service.dart';
import '../data/health/health_sync.dart';
import 'body_weight_providers.dart';
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
/// added, edited or deleted. Does nothing, and makes no calls, while off.
final healthNutritionPlanProvider = Provider<void>((ref) {
  final enabled = ref.watch(
    preferencesProvider.select((s) => s.healthWriteNutrition),
  );
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
/// at launch, when it is turned on, and when the day rolls over.
final healthWeightPlanProvider = Provider<void>((ref) {
  final enabled = ref.watch(
    preferencesProvider.select((s) => s.healthReadWeight),
  );
  final today = ref.watch(todayProvider);
  unawaited(
    ref
        .read(healthSyncProvider)
        .importWeights(enabled: enabled, today: today)
        .catchError((Object _) {}),
  );
});
