import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';

void main() {
  group('display rounding', () {
    test('calories are whole numbers', () {
      expect(Metric.calories.format(1499.6), '1500');
      expect(Metric.calories.format(0), '0');
    });

    test('macros have one decimal place', () {
      expect(Metric.protein.format(12.34), '12.3');
      expect(Metric.fat.format(5), '5.0');
    });

    test('a tiny negative value never shows as -0', () {
      expect(Metric.calories.format(-0.2), '0');
      expect(Metric.carbs.format(-0.04), '0.0');
    });
  });

  test('formatMacroLine uses the same rounding for every macro', () {
    expect(
      formatMacroLine(
        const Macros(calories: 320.4, protein: 12.34, carbs: 20, fat: 5.05),
      ),
      '320 kcal · 12.3 g protein · 20.0 g carbs · 5.1 g fat',
    );
  });

  group('optional metrics', () {
    test('sodium is in milligrams, shown without decimals', () {
      expect(Metric.sodium.unit, 'mg');
      expect(Metric.sodium.format(480.4), '480');
      expect(Metric.sodium.formatWithUnit(1500), '1500 mg');
    });

    test('fiber and sugar are grams with one decimal', () {
      expect(Metric.fiber.formatWithUnit(3.25), '3.3 g');
      expect(Metric.sugar.unit, 'g');
    });

    test('amountIn counts not recorded as 0; recordedAmountIn keeps null', () {
      const m = Macros(calories: 100, fiber: 2);
      expect(Metric.fiber.amountIn(m), 2);
      expect(Metric.sodium.amountIn(m), 0);
      expect(Metric.sodium.recordedAmountIn(m), isNull);
      expect(Metric.calories.recordedAmountIn(m), 100);
    });
  });

  group('formatMacroLine with optional nutrients', () {
    const macros = Macros(
      calories: 320,
      protein: 12,
      carbs: 20,
      fat: 5,
      fiber: 3.5,
      sodium: 480,
    );

    test('shows only the tracked nutrients that were recorded', () {
      expect(
        formatMacroLine(macros, tracked: {Metric.fiber, Metric.sodium}),
        '320 kcal · 12.0 g protein · 20.0 g carbs · 5.0 g fat · '
        '3.5 g fiber · 480 mg sodium',
      );
      expect(
        formatMacroLine(macros, tracked: {Metric.sugar, Metric.sodium}),
        '320 kcal · 12.0 g protein · 20.0 g carbs · 5.0 g fat · 480 mg sodium',
      );
    });

    test('shows none of them when nothing extra is tracked', () {
      expect(
        formatMacroLine(macros),
        '320 kcal · 12.0 g protein · 20.0 g carbs · 5.0 g fat',
      );
    });
  });

  group('coverageText', () {
    test('describes partial coverage only', () {
      expect(
        coverageText(Metric.sodium, const Coverage(recorded: 3, total: 5)),
        'Sodium recorded for 3 of 5 entries',
      );
      expect(
        coverageText(Metric.sodium, const Coverage(recorded: 5, total: 5)),
        isNull,
      );
      expect(
        coverageText(Metric.sodium, const Coverage(recorded: 0, total: 5)),
        isNull,
      );
    });
  });
}
