import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications/notification_scheduler.dart';
import '../data/notifications/reminder_sync.dart';
import 'log_providers.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

/// The OS notification scheduler. A no-op until `main` overrides it with the
/// real one, so tests and unsupported platforms never touch the plugin.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);

final reminderSyncProvider = Provider<ReminderSync>(
  (ref) => ReminderSync(ref.watch(notificationSchedulerProvider)),
);

/// Keeps the pending "nothing logged yet" notifications in line with the
/// reminder settings and today's log. Watched from the root, so it runs at
/// launch (topping up the 14-day window), when a reminder changes, when the
/// day rolls over, and when today's first entry is logged (which cancels
/// today's notifications).
final reminderPlanProvider = Provider<void>((ref) {
  final reminders = ref.watch(preferencesProvider.select((s) => s.reminders));
  final today = ref.watch(todayProvider);
  final entries = ref.watch(dayEntriesProvider(today));
  // Wait for the log to load: planning early would schedule today's reminder
  // for a user who has already logged.
  final loggedToday = entries.value?.isNotEmpty;
  if (loggedToday == null) return;
  // A scheduling failure (say, the plugin refusing) must not crash the app.
  unawaited(
    ref
        .read(reminderSyncProvider)
        .sync(
          reminders: reminders,
          now: ref.read(clockProvider)(),
          loggedToday: loggedToday,
        )
        .catchError((Object _) {}),
  );
});
