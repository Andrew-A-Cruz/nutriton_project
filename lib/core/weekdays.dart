/// Weekday masks for repeating scheduled meals. Bit 0 is Monday and bit 6 is
/// Sunday, matching [DateTime.monday] (1) .. [DateTime.sunday] (7) minus one.
library;

const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Mon-Fri.
const workweekMask = 0x1F;

/// The bit for a [DateTime.weekday] value (1 = Monday .. 7 = Sunday).
int weekdayBit(int dartWeekday) {
  if (dartWeekday < DateTime.monday || dartWeekday > DateTime.sunday) {
    throw RangeError.range(dartWeekday, 1, 7, 'dartWeekday');
  }
  return 1 << (dartWeekday - 1);
}

/// A mask from [DateTime.weekday] values.
int weekdayMask(Iterable<int> dartWeekdays) =>
    dartWeekdays.fold(0, (mask, d) => mask | weekdayBit(d));

bool maskHasWeekday(int mask, int dartWeekday) =>
    mask & weekdayBit(dartWeekday) != 0;

/// 'Every day', 'Mon-Fri', 'Weekends' or a list such as 'Mon, Wed, Fri'.
String describeWeekdays(int mask) {
  if (mask == 0x7F) return 'Every day';
  if (mask == workweekMask) return 'Mon-Fri';
  if (mask == 0x60) return 'Weekends';
  return [
    for (var i = 0; i < 7; i++)
      if (mask & (1 << i) != 0) weekdayLabels[i],
  ].join(', ');
}
