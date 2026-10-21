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
}
