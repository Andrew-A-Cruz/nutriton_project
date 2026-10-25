import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/metrics.dart';
import '../core/widget_snapshot.dart';
import '../data/widget/widget_publisher.dart';
import '../data/widget/widget_sync.dart';
import '../views/home/macro_summary.dart';
import 'log_providers.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

/// The home screen widget. A no-op until `main` overrides it with the real
/// one, so tests and unsupported platforms never touch the plugin.
final widgetPublisherProvider = Provider<WidgetPublisher>(
  (ref) => const NoopWidgetPublisher(),
);

final widgetSyncProvider = Provider<WidgetSync>(
  (ref) => WidgetSync(ref.watch(widgetPublisherProvider)),
);

/// Keeps the home screen widget in line with today's log and the primary
/// metric's goal. Watched from the root, so it runs at launch, whenever today's
/// entries, the primary metric or its goal change, and when the day rolls
/// over. Edits to other days do not touch it. (When the app is not running, the
/// widget resets itself at midnight; see `ios/TodayWidget/`.)
final widgetPlanProvider = Provider<void>((ref) {
  final metric = ref.watch(preferencesProvider.select((s) => s.primaryMetric));
  final goal = ref.watch(
    preferencesProvider.select((s) => s.goalFor(s.primaryMetric)),
  );
  final today = ref.watch(todayProvider);
  final entries = ref.watch(dayEntriesProvider(today));
  // Wait for the log to load: publishing early would show a full day left.
  final list = entries.value;
  if (list == null) return;
  final snapshot = buildWidgetSnapshot(
    dateKey: today,
    metric: metric,
    consumed: metric.amountIn(totalsOf(list)),
    goal: goal,
  );
  // A publishing failure (say, the plugin refusing) must not crash the app.
  unawaited(
    ref.read(widgetSyncProvider).sync(snapshot).catchError((Object _) {}),
  );
});
