import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/metrics.dart';
import '../core/shortcuts.dart';
import '../data/shortcuts/shortcut_logger.dart';
import '../data/shortcuts/shortcuts_bridge.dart';
import '../views/home/macro_summary.dart' show totalsOf;
import 'catalog_providers.dart';
import 'infrastructure_providers.dart';
import 'log_providers.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

/// The Siri and Shortcuts intents. A no-op until `main` overrides it on iOS,
/// so tests and other platforms never touch the plugin.
final shortcutsBridgeProvider = Provider<ShortcutsBridge>(
  (ref) => const NoopShortcutsBridge(),
);

/// What Siri can log: every saved meal except recipes (which need a
/// portion), and every starred food.
final shortcutItemsProvider = Provider<List<ShortcutItem>?>((ref) {
  final meals = ref.watch(mealsProvider).value;
  final foods = ref.watch(foodSearchProvider('')).value;
  if (meals == null || foods == null) return null;
  return [
    for (final m in meals)
      if (m.cookedWeightG == null)
        ShortcutItem(kind: ShortcutItemKind.meal, targetId: m.id, name: m.name),
    for (final f in foods)
      if (f.favorite)
        ShortcutItem(kind: ShortcutItemKind.food, targetId: f.id, name: f.name),
  ];
});

/// Keeps what the intents read in line with today's log, the primary goal
/// and the catalog. Free, unlike the widget. Watched from the root.
final shortcutsPublishPlanProvider = Provider<void>((ref) {
  final today = ref.watch(todayProvider);
  final metric = ref.watch(preferencesProvider.select((s) => s.primaryMetric));
  final goal = ref.watch(
    preferencesProvider.select((s) => s.goalFor(s.primaryMetric, date: today)),
  );
  final entries = ref.watch(dayEntriesProvider(today)).value;
  final items = ref.watch(shortcutItemsProvider);
  // Wait for both to load: publishing early would say a full day is left.
  if (entries == null || items == null) return;
  final summary = buildShortcutsSummary(
    dateKey: today,
    metric: metric,
    consumed: metric.amountIn(totalsOf(entries)),
    goal: goal,
  );
  final errorLog = ref.read(errorLogProvider);
  unawaited(
    ref
        .read(shortcutsBridgeProvider)
        .publish(summary: summary, items: items)
        .catchError(
          (Object e, StackTrace stack) => errorLog.record(
            e,
            stack,
            context: 'Could not update Siri shortcuts',
          ),
        ),
  );
});

final shortcutLoggerProvider = Provider<ShortcutLogger>(
  (ref) => ShortcutLogger(ref.watch(databaseProvider)),
);

/// Handles "log this" requests from Siri: at launch, when the app returns
/// to the foreground, and when an intent signals one while it runs. Each
/// request is taken once, so it never logs twice. Watched from the root.
class ShortcutRequestsNotifier extends Notifier<String?> {
  bool _busy = false;

  /// The name last logged by a shortcut, or null before any.
  @override
  String? build() {
    ref.keepAlive();
    final bridge = ref.watch(shortcutsBridgeProvider);
    final lifecycle = AppLifecycleListener(onResume: handle);
    final sub = bridge.requests.listen((_) => handle());
    ref.onDispose(() {
      lifecycle.dispose();
      sub.cancel();
    });
    Future.microtask(handle);
    return null;
  }

  Future<void> handle() async {
    if (_busy) return;
    _busy = true;
    try {
      final request = await ref.read(shortcutsBridgeProvider).takeRequest();
      if (request == null) return;
      final name = await ref
          .read(shortcutLoggerProvider)
          .log(request, now: ref.read(clockProvider)());
      if (name != null) state = name;
    } catch (e, stack) {
      await ref
          .read(errorLogProvider)
          .record(e, stack, context: 'Could not log from Siri');
    } finally {
      _busy = false;
    }
  }
}

final shortcutRequestsProvider =
    NotifierProvider<ShortcutRequestsNotifier, String?>(
      ShortcutRequestsNotifier.new,
    );
