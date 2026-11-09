/// When automatic backups are written and which ones are kept. Pure Dart.
library;

import 'date_key.dart';

/// At most one automatic backup per this many days.
const autoBackupIntervalDays = 7;

/// How many automatic backups are kept; older ones are deleted.
const autoBackupsKept = 5;

const _prefix = 'logbite-auto-';

/// The prefix from before the app was renamed. Those files still count, so
/// they are pruned like any other automatic backup.
const _legacyPrefix = 'nutriton-auto-';
const _suffix = '.json';

/// True when no automatic backup was written yet, or the last one is at least
/// [autoBackupIntervalDays] calendar days before [now].
bool autoBackupDue(DateTime? last, DateTime now) {
  if (last == null) return true;
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(last.year, last.month, last.day)).inDays;
  return days >= autoBackupIntervalDays;
}

/// The file name for an automatic backup written on [date]. Names sort by
/// date, so the newest is last when sorted.
String autoBackupFileName(DateTime date) => '$_prefix${dateKey(date)}$_suffix';

/// Whether [name] is an automatic backup's file name.
bool isAutoBackupFileName(String name) =>
    _prefixOf(name) != null && name.endsWith(_suffix);

String? _prefixOf(String name) => name.startsWith(_prefix)
    ? _prefix
    : name.startsWith(_legacyPrefix)
    ? _legacyPrefix
    : null;

/// The day an automatic backup was written, read from its [name], or null.
DateTime? autoBackupDate(String name) {
  if (!isAutoBackupFileName(name)) return null;
  final prefix = _prefixOf(name)!;
  try {
    return dateFromKey(
      name.substring(prefix.length, name.length - _suffix.length),
    );
  } on FormatException {
    return null;
  }
}

/// The automatic backups among [names], newest first. Other files are left
/// out. Sorted by date, not by name, so old- and new-prefix files mix.
List<String> autoBackupsNewestFirst(Iterable<String> names) => [
  for (final n in names)
    if (autoBackupDate(n) != null) n,
]..sort((a, b) => autoBackupDate(b)!.compareTo(autoBackupDate(a)!));

/// The automatic backups to delete so that only [autoBackupsKept] remain.
List<String> autoBackupsToPrune(Iterable<String> names) =>
    autoBackupsNewestFirst(names).skip(autoBackupsKept).toList();
