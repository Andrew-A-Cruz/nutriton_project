/// Wording for the backup UI, kept free of widgets so it can be unit tested.
library;

import 'package:intl/intl.dart';

String _count(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

/// What a backup file holds, e.g. `212 entries, 48 foods, 6 meals`. Scheduled
/// plans are listed only when there are some. [exportedAt] adds a second line
/// such as `Exported Oct 21, 2026`.
String backupSummary({
  required int entries,
  required int foods,
  required int meals,
  int plans = 0,
  DateTime? exportedAt,
}) {
  final parts = [
    _count(entries, 'entry', 'entries'),
    _count(foods, 'food', 'foods'),
    _count(meals, 'meal', 'meals'),
    if (plans > 0) _count(plans, 'scheduled plan', 'scheduled plans'),
  ];
  final line = parts.join(', ');
  if (exportedAt == null) return line;
  return '$line\nExported ${DateFormat.yMMMd().format(exportedAt)}';
}

/// The Settings footer for the last successful export, counted in calendar
/// days (not 24-hour periods) between [last] and [now].
String lastBackupLabel(DateTime? last, DateTime now) {
  if (last == null) return 'Never backed up';
  final days = _utcDay(now).difference(_utcDay(last)).inDays;
  return switch (days) {
    <= 0 => 'Last backup: today',
    1 => 'Last backup: yesterday',
    _ => 'Last backup: $days days ago',
  };
}

/// Midnight of [d]'s local calendar day as a UTC instant, so subtracting two
/// of them is an exact whole number of days even across a DST change.
DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);
