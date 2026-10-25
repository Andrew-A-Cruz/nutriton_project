import 'date_key.dart';

/// The current logging streak: how many consecutive days, ending [today], have
/// at least one entry. [loggedDates] are 'yyyy-MM-dd' keys.
///
/// If [today] has no entry yet the streak ends yesterday instead, so a streak
/// is not shown as broken during the day before the first meal is logged. It
/// only drops to 0 once a whole day has passed with nothing logged. Dates after
/// [today] (logged ahead of time) are ignored.
int currentStreak(Iterable<String> loggedDates, {required String today}) {
  final days = loggedDates is Set<String> ? loggedDates : loggedDates.toSet();
  var day = days.contains(today) ? today : addDays(today, -1);
  var count = 0;
  while (days.contains(day)) {
    count++;
    day = addDays(day, -1);
  }
  return count;
}
