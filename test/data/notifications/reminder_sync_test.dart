import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/reminder.dart';
import 'package:nutriton_project/data/notifications/reminder_sync.dart';

import '../../support/fake_notification_scheduler.dart';

void main() {
  const reminders = [
    Reminder(minutes: 9 * 60, enabled: true),
    Reminder(minutes: 13 * 60),
    Reminder(minutes: 19 * 60, enabled: true),
  ];
  final now = DateTime(2026, 10, 21, 8);
  late FakeNotificationScheduler scheduler;
  late ReminderSync sync;

  setUp(() {
    scheduler = FakeNotificationScheduler();
    sync = ReminderSync(scheduler);
  });

  test('schedules 14 days of the enabled reminders', () async {
    await sync.sync(reminders: reminders, now: now, loggedToday: false);
    expect(scheduler.pending, hasLength(28));
    expect(scheduler.pendingTimes.first, DateTime(2026, 10, 21, 9));
    expect(scheduler.pending.values.first.body, 'Nothing logged yet today');
  });

  test("logging today cancels only today's", () async {
    await sync.sync(reminders: reminders, now: now, loggedToday: false);
    await sync.sync(reminders: reminders, now: now, loggedToday: true);
    expect(scheduler.pending, hasLength(26));
    expect(scheduler.pendingTimes.first, DateTime(2026, 10, 22, 9));
  });

  test('topping up on a later launch is idempotent', () async {
    await sync.sync(reminders: reminders, now: now, loggedToday: false);
    final first = Map.of(scheduler.pending);
    await sync.sync(reminders: reminders, now: now, loggedToday: false);
    expect(scheduler.pending, first);

    // Two days later the window has moved on; nothing stale remains.
    final later = DateTime(2026, 10, 23, 8);
    await sync.sync(reminders: reminders, now: later, loggedToday: false);
    expect(scheduler.pending, hasLength(28));
    expect(scheduler.pendingTimes.first, DateTime(2026, 10, 23, 9));
    expect(scheduler.pendingTimes.last, DateTime(2026, 11, 5, 19));
    await sync.sync(reminders: reminders, now: later, loggedToday: false);
    expect(scheduler.pending, hasLength(28));
  });

  test('turning every reminder off clears the schedule', () async {
    await sync.sync(reminders: reminders, now: now, loggedToday: false);
    await sync.sync(reminders: Reminder.defaults, now: now, loggedToday: false);
    expect(scheduler.pending, isEmpty);
  });

  test('never asks for permission', () async {
    await sync.sync(reminders: reminders, now: now, loggedToday: false);
    expect(scheduler.permissionRequests, 0);
  });
}
