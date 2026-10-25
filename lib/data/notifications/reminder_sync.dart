import '../../core/reminder.dart';
import 'notification_scheduler.dart';

/// Makes the scheduler's pending notifications match the reminders. Safe to
/// call as often as wanted: each call replaces everything pending with the
/// plan from [planNudges], so repeating it with the same input changes nothing.
class ReminderSync {
  ReminderSync(this._scheduler);

  final NotificationScheduler _scheduler;

  // Calls run one after another, so a slow earlier one cannot cancel what a
  // later one has just scheduled.
  Future<void> _tail = Future.value();

  static const title = 'Nutriton';
  static const body = 'Nothing logged yet today';

  Future<void> sync({
    required List<Reminder> reminders,
    required DateTime now,
    required bool loggedToday,
  }) {
    final run = _tail.then((_) async {
      await _scheduler.cancelAll();
      final plan = planNudges(
        reminders: reminders,
        now: now,
        loggedToday: loggedToday,
      );
      for (final nudge in plan) {
        await _scheduler.schedule(
          id: nudge.id,
          when: nudge.when,
          title: title,
          body: body,
        );
      }
    });
    // A failed run must not block the next one.
    _tail = run.catchError((Object _) {});
    return run;
  }
}
