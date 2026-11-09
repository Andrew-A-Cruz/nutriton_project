import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/report.dart';

void main() {
  const start = '2026-10-01';
  const end = '2026-10-07';

  Macros day(double kcal, {double protein = 100, double? sodium}) => Macros(
    calories: kcal,
    protein: protein,
    carbs: 200,
    fat: 60,
    sodium: sodium,
  );

  ShareableReport build({
    Map<String, Macros> days = const {},
    Map<Metric, double> goals = const {},
    List<({String date, double kg})> weights = const [],
    List<Metric> metrics = const [Metric.calories, Metric.protein],
  }) => buildReport(
    startKey: start,
    endKey: end,
    days: days,
    metrics: metrics,
    goals: goals,
    weights: weights,
  );

  test('averages over logged days only, ignoring days outside the range', () {
    final r = build(
      days: {
        '2026-09-30': day(9000),
        '2026-10-02': day(1800, protein: 90),
        '2026-10-05': day(2200, protein: 110),
        '2026-10-08': day(9000),
      },
    );
    expect(r.totalDays, 7);
    expect(r.daysLogged, 2);
    expect([for (final d in r.days) d.date], ['2026-10-02', '2026-10-05']);
    expect(r.rows[0].metric, Metric.calories);
    expect(r.rows[0].average, 2000);
    expect(r.rows[1].average, 100);
  });

  test('goals give a percentage and days on target; no goal gives neither', () {
    final r = build(
      days: {
        '2026-10-01': day(1500),
        '2026-10-02': day(2000),
        '2026-10-03': day(2150),
      },
      goals: {Metric.calories: 2000},
    );
    final kcal = r.rows[0];
    expect(kcal.goal, 2000);
    expect(kcal.percentOfGoal, 94); // 1883.3 / 2000
    expect(kcal.daysOnTarget, 2); // 2000 and 2150 are within 10%
    final protein = r.rows[1];
    expect(protein.goal, isNull);
    expect(protein.percentOfGoal, isNull);
    expect(protein.daysOnTarget, isNull);
  });

  test('an optional metric never recorded has no average', () {
    final r = build(
      days: {'2026-10-01': day(2000)},
      metrics: const [Metric.calories, Metric.sodium],
    );
    expect(r.rows[1].average, isNull);
  });

  test('an empty range has no averages and no days', () {
    final r = build(goals: {Metric.calories: 2000});
    expect(r.daysLogged, 0);
    expect(r.rows[0].average, isNull);
    expect(r.rows[0].percentOfGoal, isNull);
    expect(r.rows[0].daysOnTarget, 0);
    expect(r.weight, isNull);
  });

  test('weight uses the first and last weigh-in inside the range', () {
    final r = build(
      weights: const [
        (date: '2026-09-28', kg: 90),
        (date: '2026-10-06', kg: 79.0),
        (date: '2026-10-02', kg: 80.5),
        (date: '2026-10-04', kg: 80.0),
      ],
    );
    expect(r.weight!.first.date, '2026-10-02');
    expect(r.weight!.last.date, '2026-10-06');
    expect(r.weight!.count, 3);
    expect(r.weight!.changeKg, closeTo(-1.5, 1e-9));
  });

  test('file names carry the range', () {
    expect(
      reportFileName('2026-10-10', '2026-11-08'),
      'logbite-report-2026-10-10-to-2026-11-08.pdf',
    );
    expect(reportFileName(end, end), 'logbite-report-2026-10-07.pdf');
  });
}
