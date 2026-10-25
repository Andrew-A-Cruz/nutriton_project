import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/widget_snapshot.dart';

WidgetSnapshot snapshot(Metric metric, double consumed, double? goal) =>
    buildWidgetSnapshot(
      dateKey: '2026-10-21',
      metric: metric,
      consumed: consumed,
      goal: goal,
    );

void main() {
  group('buildWidgetSnapshot', () {
    test('without a goal shows what was eaten and no progress', () {
      final s = snapshot(Metric.calories, 640, null);
      expect(s.valueText, '640');
      expect(s.caption, 'kcal eaten');
      expect(s.emptyValueText, '0');
      expect(s.progress, 0);
      expect(s.overGoal, isFalse);
      expect(s.dateKey, '2026-10-21');
    });

    test('a zero goal counts as no goal', () {
      final s = snapshot(Metric.calories, 640, 0);
      expect(s.caption, 'kcal eaten');
      expect(s.progress, 0);
    });

    test('under the goal shows the amount left', () {
      final s = snapshot(Metric.calories, 500, 2000);
      expect(s.valueText, '1500');
      expect(s.caption, 'kcal left');
      expect(s.emptyValueText, '2000');
      expect(s.progress, 0.25);
      expect(s.overGoal, isFalse);
    });

    test('nothing logged shows the whole goal and an empty ring', () {
      final s = snapshot(Metric.calories, 0, 2000);
      expect(s.valueText, '2000');
      expect(s.progress, 0);
    });

    test('exactly on the goal is full, not over', () {
      final s = snapshot(Metric.calories, 2000, 2000);
      expect(s.valueText, '0');
      expect(s.caption, 'kcal left');
      expect(s.progress, 1);
      expect(s.overGoal, isFalse);
    });

    test('over the goal shows the excess and clamps progress to 1', () {
      final s = snapshot(Metric.calories, 2300, 2000);
      expect(s.valueText, '300');
      expect(s.caption, 'kcal over');
      expect(s.progress, 1);
      expect(s.overGoal, isTrue);
    });

    test('a primary metric other than calories names itself', () {
      final s = snapshot(Metric.protein, 62.5, 150);
      expect(s.valueText, '87.5');
      expect(s.caption, 'g protein left');
      expect(s.emptyValueText, '150.0');
      expect(s.progress, closeTo(62.5 / 150, 1e-9));
    });

    test('sodium is shown in whole mg', () {
      final s = snapshot(Metric.sodium, 2600.4, 2300);
      expect(s.valueText, '300');
      expect(s.caption, 'mg sodium over');
    });

    test('rounds before comparing, so over never sits beside 0 left', () {
      final s = snapshot(Metric.calories, 2000.4, 2000);
      expect(s.valueText, '0');
      expect(s.caption, 'kcal left');
      expect(s.overGoal, isFalse);
      expect(s.progress, 1);

      final t = snapshot(Metric.calories, 2000.6, 2000);
      expect(t.valueText, '1');
      expect(t.caption, 'kcal over');
      expect(t.overGoal, isTrue);
    });

    test('rounds grams to one decimal without float noise', () {
      final s = snapshot(Metric.carbs, 0.1 + 0.2, 1);
      expect(s.valueText, '0.7');
    });

    test('toMap holds the keys the widget reads', () {
      final map = snapshot(Metric.calories, 500, 2000).toMap();
      expect(map.keys, [
        'date_key',
        'value_text',
        'caption',
        'empty_value_text',
        'progress',
        'over_goal',
      ]);
    });

    test('equal figures compare equal', () {
      expect(
        snapshot(Metric.calories, 500, 2000),
        snapshot(Metric.calories, 500, 2000),
      );
      expect(
        snapshot(Metric.calories, 500, 2000),
        isNot(snapshot(Metric.calories, 600, 2000)),
      );
    });
  });
}
