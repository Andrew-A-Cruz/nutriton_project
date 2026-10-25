import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/health.dart';
import 'package:nutriton_project/core/nutrition_math.dart';

void main() {
  group('nutritionSamples', () {
    test('writes energy and the macros, in order', () {
      final samples = nutritionSamples(
        const Macros(calories: 2100, protein: 150, carbs: 220, fat: 70),
      );

      expect(samples, [
        (
          type: HealthNutrient.energy,
          value: 2100.0,
          unit: HealthUnit.kilocalorie,
        ),
        (type: HealthNutrient.protein, value: 150.0, unit: HealthUnit.gram),
        (type: HealthNutrient.carbs, value: 220.0, unit: HealthUnit.gram),
        (type: HealthNutrient.fat, value: 70.0, unit: HealthUnit.gram),
      ]);
    });

    test('leaves out nutrients that were never recorded', () {
      final samples = nutritionSamples(
        const Macros(calories: 500, protein: 20, carbs: 60, fat: 10, fiber: 8),
      );

      expect(samples.map((s) => s.type), [
        HealthNutrient.energy,
        HealthNutrient.protein,
        HealthNutrient.carbs,
        HealthNutrient.fat,
        HealthNutrient.fiber,
      ]);
    });

    test('adds fiber, sugar and sodium when recorded', () {
      final samples = nutritionSamples(
        const Macros(
          calories: 500,
          protein: 20,
          carbs: 60,
          fat: 10,
          fiber: 8,
          sugar: 12.5,
          sodium: 900,
        ),
      );

      expect(samples.map((s) => s.type).toList().sublist(4), [
        HealthNutrient.fiber,
        HealthNutrient.sugar,
        HealthNutrient.sodium,
      ]);
      expect(samples[5].value, 12.5);
    });

    test('sodium goes in grams: milligrams divided by 1000', () {
      final sodium = nutritionSamples(
        const Macros(calories: 100, sodium: 1500),
      ).singleWhere((s) => s.type == HealthNutrient.sodium);

      expect(sodium.value, 1.5);
      expect(sodium.unit, HealthUnit.gram);
    });

    test('a day with nothing logged has no samples', () {
      expect(nutritionSamples(Macros.zero), isEmpty);
    });

    test('a recorded 0 is not written either', () {
      final samples = nutritionSamples(
        const Macros(calories: 100, fiber: 0, sugar: 0, sodium: 0),
      );

      expect(samples.map((s) => s.type), [HealthNutrient.energy]);
    });
  });

  group('dailyWeights', () {
    test('keeps the latest reading of each day, oldest day first', () {
      final weights = dailyWeights([
        (when: DateTime(2026, 10, 21, 20), kg: 80.0),
        (when: DateTime(2026, 10, 20, 7), kg: 81.0),
        (when: DateTime(2026, 10, 21, 7), kg: 80.4),
      ]);

      expect(weights, [
        (date: '2026-10-20', kg: 81.0),
        (date: '2026-10-21', kg: 80.0),
      ]);
    });

    test('drops readings outside the accepted range', () {
      final weights = dailyWeights([
        (when: DateTime(2026, 10, 20, 7), kg: 5.0),
        (when: DateTime(2026, 10, 21, 7), kg: 800.0),
        (when: DateTime(2026, 10, 22, 7), kg: double.nan),
        (when: DateTime(2026, 10, 23, 7), kg: 79.0),
      ]);

      expect(weights, [(date: '2026-10-23', kg: 79.0)]);
    });
  });
}
