import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/health.dart';

void main() {
  group('dailySteps', () {
    test('adds up stretches by the local day they start on', () {
      expect(
        dailySteps([
          (from: DateTime(2026, 11, 12, 8), steps: 1200.4),
          (from: DateTime(2026, 11, 12, 23), steps: 300.4),
          (from: DateTime(2026, 11, 13, 0), steps: 50),
        ]),
        {'2026-11-12': 1501, '2026-11-13': 50},
      );
    });

    test('skips nothing, negative and non-finite stretches', () {
      expect(
        dailySteps([
          (from: DateTime(2026, 11, 12, 8), steps: 0),
          (from: DateTime(2026, 11, 12, 9), steps: -5),
          (from: DateTime(2026, 11, 12, 10), steps: double.nan),
        ]),
        isEmpty,
      );
    });
  });

  test('stepsProgressText shows the goal only when set', () {
    String f(int n) => '<$n>';
    expect(stepsProgressText(10, null, format: f), '<10>');
    expect(stepsProgressText(10, 0, format: f), '<10>');
    expect(stepsProgressText(10, 500, format: f), '<10> / <500>');
  });

  test('averageDailySteps counts only days with steps', () {
    expect(averageDailySteps(const {}), isNull);
    expect(averageDailySteps(const {'a': 0}), isNull);
    expect(averageDailySteps(const {'a': 1000, 'b': 2001, 'c': 0}), 1501);
  });
}
