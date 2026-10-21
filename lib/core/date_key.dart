/// Conversions between [DateTime] and the 'yyyy-MM-dd' day keys stored in
/// `food_log_entries.log_date`. Keys are calendar days, so they never depend on
/// time zone or time of day.
library;

String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a 'yyyy-MM-dd' key into a local date at midnight.
/// Throws [FormatException] for malformed or non-existent dates.
DateTime dateFromKey(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) {
    throw FormatException('Invalid date key', key);
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Non-existent calendar date', key);
  }
  return date;
}

/// The key [days] calendar days after [key] (negative goes backwards).
/// Uses UTC arithmetic so daylight-saving shifts cannot move the result.
String addDays(String key, int days) {
  final d = dateFromKey(key);
  final shifted = DateTime.utc(d.year, d.month, d.day + days);
  return dateKey(shifted);
}

/// The key for [now] (defaults to the current time).
String todayKey([DateTime? now]) => dateKey(now ?? DateTime.now());
