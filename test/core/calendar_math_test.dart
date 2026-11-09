import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/calendar_math.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';

void main() {
  test('November 2026 starts on a Sunday and spans five weeks', () {
    final grid = monthGrid((year: 2026, month: 11));
    expect(grid, hasLength(5));
    expect(grid.first.first, '2026-11-01');
    expect(grid.last.take(2), ['2026-11-29', '2026-11-30']);
    expect(grid.last.skip(2), everyElement(isNull));
  });

  test('a month starting midweek is padded at the front', () {
    final grid = monthGrid((year: 2026, month: 10)); // Thursday the 1st
    expect(grid.first, [
      null,
      null,
      null,
      null,
      '2026-10-01',
      '2026-10-02',
      '2026-10-03',
    ]);
    expect(grid.expand((w) => w).whereType<String>(), hasLength(31));
  });

  test('February in a leap year', () {
    final days = monthGrid((
      year: 2028,
      month: 2,
    )).expand((w) => w).whereType<String>();
    expect(days.last, '2028-02-29');
  });

  test('months step across years', () {
    expect(addMonths((year: 2026, month: 12), 1), (year: 2027, month: 1));
    expect(addMonths((year: 2026, month: 1), -1), (year: 2025, month: 12));
    expect(monthOf('2026-11-09'), (year: 2026, month: 11));
    expect(monthSpan((year: 2026, month: 2)), ('2026-02-01', '2026-02-28'));
  });

  test('marks follow the goal, within 10%', () {
    Macros kcal(double c) => Macros(calories: c, protein: 0, carbs: 0, fat: 0);
    expect(dayMark(null, Metric.calories, 2000), DayMark.none);
    expect(dayMark(kcal(1500), Metric.calories, null), DayMark.logged);
    expect(dayMark(kcal(1500), Metric.calories, 2000), DayMark.under);
    expect(dayMark(kcal(2100), Metric.calories, 2000), DayMark.onTarget);
    expect(dayMark(kcal(2500), Metric.calories, 2000), DayMark.over);
  });
}
