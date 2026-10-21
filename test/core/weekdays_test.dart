import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/weekdays.dart';

void main() {
  test('weekdayBit maps Monday to bit 0 and Sunday to bit 6', () {
    expect(weekdayBit(DateTime.monday), 1);
    expect(weekdayBit(DateTime.sunday), 64);
    expect(() => weekdayBit(0), throwsRangeError);
    expect(() => weekdayBit(8), throwsRangeError);
  });

  test('weekdayMask and maskHasWeekday round-trip', () {
    final mask = weekdayMask([1, 3, 5]);
    expect(mask, 0x15);
    expect(maskHasWeekday(mask, DateTime.wednesday), isTrue);
    expect(maskHasWeekday(mask, DateTime.tuesday), isFalse);
    expect(weekdayMask([1, 2, 3, 4, 5]), workweekMask);
  });

  test('describeWeekdays', () {
    expect(describeWeekdays(workweekMask), 'Mon-Fri');
    expect(describeWeekdays(0x7F), 'Every day');
    expect(describeWeekdays(0x60), 'Weekends');
    expect(describeWeekdays(weekdayMask([1, 3, 5])), 'Mon, Wed, Fri');
  });
}
