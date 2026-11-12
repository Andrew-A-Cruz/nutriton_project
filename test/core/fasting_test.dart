import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/fasting.dart';

void main() {
  test('length is the time between start and end, never negative', () {
    final start = DateTime(2026, 11, 11, 20);
    expect(
      fastLength(start, DateTime(2026, 11, 12, 12)),
      const Duration(hours: 16),
    );
    expect(fastLength(start, DateTime(2026, 11, 11, 19)), Duration.zero);
  });

  test('formats minutes, hours and days, rounding down', () {
    expect(formatFastLength(Duration.zero), '0m');
    expect(formatFastLength(const Duration(seconds: 59)), '0m');
    expect(formatFastLength(const Duration(minutes: 45)), '45m');
    expect(formatFastLength(const Duration(hours: 13, minutes: 20)), '13h 20m');
    expect(formatFastLength(const Duration(hours: 16)), '16h 0m');
    expect(
      formatFastLength(const Duration(days: 2, hours: 4, minutes: 5)),
      '2d 4h 5m',
    );
    expect(formatFastLength(const Duration(minutes: -5)), '0m');
  });
}
