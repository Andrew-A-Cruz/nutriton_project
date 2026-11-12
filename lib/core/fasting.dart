/// Fasting timer arithmetic: how long a fast has run and how to show it.
/// Pure Dart.
library;

/// How long a fast that began at [startedAt] has lasted at [end]. Never
/// negative, so a clock that moved backwards reads as zero.
Duration fastLength(DateTime startedAt, DateTime end) {
  final length = end.difference(startedAt);
  return length.isNegative ? Duration.zero : length;
}

/// '45m', '13h 20m' or '2d 4h 5m'. Whole minutes, rounded down.
String formatFastLength(Duration length) {
  final minutes = length.isNegative ? 0 : length.inMinutes;
  final d = minutes ~/ (24 * 60);
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  if (d > 0) return '${d}d ${h}h ${m}m';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
