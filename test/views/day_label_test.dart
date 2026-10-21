import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/views/home/date_header.dart';

void main() {
  group('dayLabel', () {
    const today = '2026-10-20';

    test('says Today and Yesterday', () {
      expect(dayLabel('2026-10-20', today: today), 'Today');
      expect(dayLabel('2026-10-19', today: today), 'Yesterday');
    });

    test('omits the year within the current year', () {
      expect(dayLabel('2026-10-12', today: today), 'Mon, Oct 12');
      expect(dayLabel('2026-01-01', today: today), 'Thu, Jan 1');
    });

    test('includes the year for other years', () {
      expect(dayLabel('2025-10-20', today: today), 'Mon, Oct 20, 2025');
      expect(dayLabel('2027-01-04', today: today), 'Mon, Jan 4, 2027');
    });

    test('Yesterday across a year boundary stays Yesterday', () {
      expect(dayLabel('2025-12-31', today: '2026-01-01'), 'Yesterday');
      expect(dayLabel('2025-12-30', today: '2026-01-01'), 'Tue, Dec 30, 2025');
    });
  });
}
