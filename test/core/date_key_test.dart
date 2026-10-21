import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';

void main() {
  group('dateKey', () {
    test('formats with zero padding', () {
      expect(dateKey(DateTime(2026, 10, 5)), '2026-10-05');
    });

    test('ignores the time of day', () {
      expect(dateKey(DateTime(2026, 10, 20, 23, 59, 59)), '2026-10-20');
      expect(dateKey(DateTime(2026, 10, 20, 0, 0, 1)), '2026-10-20');
    });

    test('pads a four-digit year', () {
      expect(dateKey(DateTime(999, 1, 2)), '0999-01-02');
    });
  });

  group('dateFromKey', () {
    test('round-trips with dateKey', () {
      expect(dateKey(dateFromKey('2026-10-20')), '2026-10-20');
    });

    test('accepts leap day in a leap year', () {
      expect(dateFromKey('2028-02-29'), DateTime(2028, 2, 29));
    });

    test('rejects a leap day in a non-leap year', () {
      expect(() => dateFromKey('2026-02-29'), throwsFormatException);
    });

    test('rejects malformed keys', () {
      expect(() => dateFromKey('Oct 20'), throwsFormatException);
      expect(() => dateFromKey('2026-1-05'), throwsFormatException);
      expect(() => dateFromKey('2026-10-20T00:00'), throwsFormatException);
      expect(() => dateFromKey(''), throwsFormatException);
    });
  });

  group('addDays', () {
    test('moves forward and backward across a month boundary', () {
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(addDays('2026-10-31', 1), '2026-11-01');
    });

    test('crosses a leap day', () {
      expect(addDays('2028-02-28', 1), '2028-02-29');
      expect(addDays('2028-02-29', 1), '2028-03-01');
    });

    test('crosses a year boundary', () {
      expect(addDays('2026-12-31', 1), '2027-01-01');
    });

    test('zero is the same day', () {
      expect(addDays('2026-10-20', 0), '2026-10-20');
    });

    test('a 7-day window ending today starts six days back', () {
      expect(addDays('2026-10-20', -6), '2026-10-14');
    });

    test('is not shifted by the US spring-forward DST change', () {
      // 2026-03-08 is a DST transition in the US. Calendar arithmetic must
      // still land on the next calendar day.
      expect(addDays('2026-03-07', 1), '2026-03-08');
      expect(addDays('2026-03-09', -1), '2026-03-08');
    });
  });

  test('todayKey uses the calendar day of the supplied time', () {
    expect(todayKey(DateTime(2026, 10, 20, 23, 59)), '2026-10-20');
  });

  test('keys sort chronologically as strings', () {
    final keys = ['2026-10-02', '2025-12-31', '2026-01-15', '2026-10-01'];
    keys.sort();
    expect(keys, ['2025-12-31', '2026-01-15', '2026-10-01', '2026-10-02']);
  });
}
