import 'date_key.dart';

/// How many reminder slots Settings offers.
const reminderSlots = 3;

/// How many days ahead "nothing logged yet" notifications are scheduled.
const nudgeWindowDays = 14;

/// One daily reminder: a time of day and whether it is on. Off by default.
class Reminder {
  const Reminder({required this.minutes, this.enabled = false});

  /// Minutes after local midnight, 0 to 1439.
  final int minutes;
  final bool enabled;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  Reminder copyWith({int? minutes, bool? enabled}) => Reminder(
    minutes: minutes ?? this.minutes,
    enabled: enabled ?? this.enabled,
  );

  /// Morning, lunch and evening, all off.
  static const defaults = [
    Reminder(minutes: 9 * 60),
    Reminder(minutes: 13 * 60),
    Reminder(minutes: 19 * 60),
  ];

  @override
  bool operator ==(Object other) =>
      other is Reminder && other.minutes == minutes && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(minutes, enabled);

  @override
  String toString() => 'Reminder($hour:$minute, enabled: $enabled)';
}

/// One notification to schedule, at a local wall-clock time.
class PlannedNudge {
  const PlannedNudge({required this.id, required this.when});

  final int id;
  final DateTime when;

  @override
  bool operator ==(Object other) =>
      other is PlannedNudge && other.id == id && other.when == when;

  @override
  int get hashCode => Object.hash(id, when);

  @override
  String toString() => 'PlannedNudge($id, $when)';
}

/// A stable id for the notification of reminder [slot] on [dateKey], so
/// scheduling the same day twice replaces rather than duplicates.
int nudgeId(String dateKey, int slot) {
  final d = dateFromKey(dateKey);
  final epochDay =
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return epochDay * reminderSlots + slot;
}

/// The one-off "nothing logged yet" notifications to have pending: each enabled
/// reminder on each of the next [days] days starting today, skipping times that
/// have already passed at [now]. Today is skipped entirely once
/// [loggedToday], since the notification says nothing has been logged.
///
/// One-offs rather than repeating notifications, because the OS cannot check
/// the log when one fires (iOS cannot run code in the background for this).
/// The app re-plans on every launch, so the window keeps moving forward.
List<PlannedNudge> planNudges({
  required List<Reminder> reminders,
  required DateTime now,
  required bool loggedToday,
  int days = nudgeWindowDays,
}) {
  final today = todayKey(now);
  final nudges = <PlannedNudge>[];
  for (var offset = 0; offset < days; offset++) {
    if (offset == 0 && loggedToday) continue;
    final key = addDays(today, offset);
    final date = dateFromKey(key);
    for (var slot = 0; slot < reminders.length; slot++) {
      final r = reminders[slot];
      if (!r.enabled) continue;
      final when = DateTime(date.year, date.month, date.day, r.hour, r.minute);
      if (!when.isAfter(now)) continue;
      nudges.add(PlannedNudge(id: nudgeId(key, slot), when: when));
    }
  }
  return nudges;
}
