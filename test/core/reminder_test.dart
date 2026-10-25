import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/reminder.dart';

void main() {
  const morning = Reminder(minutes: 9 * 60, enabled: true);
  const evening = Reminder(minutes: 19 * 60 + 30, enabled: true);
  const off = Reminder(minutes: 12 * 60);

  test('all reminders are off by default', () {
    expect(Reminder.defaults, hasLength(reminderSlots));
    expect(Reminder.defaults.every((r) => !r.enabled), isTrue);
  });

  test('nothing is planned when every reminder is off', () {
    expect(
      planNudges(
        reminders: [off, off, off],
        now: DateTime(2026, 10, 21, 8),
        loggedToday: false,
      ),
      isEmpty,
    );
  });

  test('plans each enabled reminder for the next 14 days', () {
    final plan = planNudges(
      reminders: [morning, off, evening],
      now: DateTime(2026, 10, 21, 8),
      loggedToday: false,
    );
    expect(plan, hasLength(28));
    expect(plan.first.when, DateTime(2026, 10, 21, 9));
    expect(plan.last.when, DateTime(2026, 11, 3, 19, 30));
    expect(plan.map((n) => n.id).toSet(), hasLength(28));
  });

  test("today's reminders that have already passed are skipped", () {
    final plan = planNudges(
      reminders: [morning, evening],
      now: DateTime(2026, 10, 21, 10),
      loggedToday: false,
    );
    expect(plan, hasLength(27));
    expect(plan.first.when, DateTime(2026, 10, 21, 19, 30));
  });

  test('a reminder exactly now is not planned', () {
    final plan = planNudges(
      reminders: [morning],
      now: DateTime(2026, 10, 21, 9),
      loggedToday: false,
    );
    expect(plan.first.when, DateTime(2026, 10, 22, 9));
  });

  test("once today is logged, today's reminders are dropped", () {
    final plan = planNudges(
      reminders: [morning, evening],
      now: DateTime(2026, 10, 21, 8),
      loggedToday: true,
    );
    expect(plan, hasLength(26));
    expect(plan.first.when, DateTime(2026, 10, 22, 9));
  });

  test('ids are stable per day and slot, so a re-plan replaces', () {
    final a = planNudges(
      reminders: [morning, evening],
      now: DateTime(2026, 10, 21, 8),
      loggedToday: false,
    );
    final b = planNudges(
      reminders: [morning, evening],
      now: DateTime(2026, 10, 21, 8, 30),
      loggedToday: false,
    );
    expect(b, a);
    // Tomorrow's plan shares 13 days (26 notifications) with today's.
    final tomorrow = planNudges(
      reminders: [morning, evening],
      now: DateTime(2026, 10, 22, 8),
      loggedToday: false,
    );
    expect(a.where(tomorrow.contains), hasLength(26));
  });

  test('the window crosses month and year ends', () {
    final plan = planNudges(
      reminders: [morning],
      now: DateTime(2026, 12, 25, 8),
      loggedToday: false,
    );
    expect(plan.last.when, DateTime(2027, 1, 7, 9));
  });
}
