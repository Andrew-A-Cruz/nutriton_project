import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';

void main() {
  const chicken = Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6);

  group('scaleByServings', () {
    test('multiplies every macro by the serving count', () {
      final result = scaleByServings(chicken, 1.5);
      expect(result.calories, closeTo(247.5, 1e-9));
      expect(result.protein, closeTo(46.5, 1e-9));
      expect(result.carbs, 0);
      expect(result.fat, closeTo(5.4, 1e-9));
    });

    test('zero servings gives zero macros', () {
      expect(scaleByServings(chicken, 0), Macros.zero);
    });

    test('one serving is unchanged', () {
      expect(scaleByServings(chicken, 1), chicken);
    });

    test('negative servings throw', () {
      expect(() => scaleByServings(chicken, -1), throwsArgumentError);
    });
  });

  group('scaleByWeight', () {
    test('weight equal to the serving weight gives one serving', () {
      final result = scaleByWeight(chicken, servingWeightG: 100, weightG: 100);
      expect(result, chicken);
    });

    test('a 100 g food eaten at 200 g doubles', () {
      final result = scaleByWeight(chicken, servingWeightG: 100, weightG: 200);
      expect(result.calories, closeTo(330, 1e-9));
    });

    test('ratio uses grams, so 4 oz against a 100 g serving is 1.134', () {
      // This is the bug the grams normalization fixes: a raw ratio of
      // 4 / 100 would give 0.04 instead of ~1.134.
      final grams = WeightUnit.oz.toGrams(4);
      final result = scaleByWeight(
        chicken,
        servingWeightG: 100,
        weightG: grams,
      );
      expect(result.calories, closeTo(165 * 1.13398, 1e-6));
    });

    test('zero weight gives zero macros', () {
      expect(
        scaleByWeight(chicken, servingWeightG: 100, weightG: 0),
        Macros.zero,
      );
    });

    test('a zero serving weight throws (it is a divisor)', () {
      expect(
        () => scaleByWeight(chicken, servingWeightG: 0, weightG: 50),
        throwsArgumentError,
      );
    });

    test('negative weight throws', () {
      expect(
        () => scaleByWeight(chicken, servingWeightG: 100, weightG: -5),
        throwsArgumentError,
      );
    });
  });

  group('servingsForWeight', () {
    test('weight equal to the serving weight is one serving', () {
      expect(
        servingsForWeight(weightG: 100, servingWeightG: 100),
        closeTo(1, 1e-9),
      );
    });

    test('150 g of a 100 g serving is 1.5 servings', () {
      expect(
        servingsForWeight(weightG: 150, servingWeightG: 100),
        closeTo(1.5, 1e-9),
      );
    });

    test('4 oz against a 100 g serving is about 1.134 servings', () {
      final grams = WeightUnit.oz.toGrams(4);
      expect(
        servingsForWeight(weightG: grams, servingWeightG: 100),
        closeTo(1.13398, 1e-5),
      );
    });

    test('zero weight is zero servings', () {
      expect(servingsForWeight(weightG: 0, servingWeightG: 100), 0);
    });

    test('a zero serving weight throws (it is a divisor)', () {
      expect(
        () => servingsForWeight(weightG: 100, servingWeightG: 0),
        throwsArgumentError,
      );
    });

    test('negative weight throws', () {
      expect(
        () => servingsForWeight(weightG: -1, servingWeightG: 100),
        throwsArgumentError,
      );
    });
  });

  group('sumMacros', () {
    test('empty list sums to zero', () {
      expect(sumMacros(const []), Macros.zero);
    });

    test('adds every item', () {
      final total = sumMacros([
        chicken,
        const Macros(calories: 205, protein: 4.3, carbs: 45, fat: 0.4),
      ]);
      expect(total.calories, closeTo(370, 1e-9));
      expect(total.protein, closeTo(35.3, 1e-9));
      expect(total.carbs, closeTo(45, 1e-9));
      expect(total.fat, closeTo(4.0, 1e-9));
    });
  });

  group('weight units', () {
    test('1 oz is 28.3495 g', () {
      expect(gramsPerOunce, 28.3495);
      expect(WeightUnit.oz.toGrams(1), closeTo(28.3495, 1e-12));
    });

    test('grams pass through unchanged', () {
      expect(WeightUnit.g.toGrams(150), 150);
      expect(WeightUnit.g.fromGrams(150), 150);
    });

    test('oz <-> g round trip', () {
      final grams = WeightUnit.oz.toGrams(6);
      expect(WeightUnit.oz.fromGrams(grams), closeTo(6, 1e-9));
    });

    test('zero converts to zero', () {
      expect(WeightUnit.oz.toGrams(0), 0);
      expect(WeightUnit.oz.fromGrams(0), 0);
    });
  });

  group('roundTo', () {
    test('rounds to whole numbers, halves away from zero', () {
      expect(roundTo(2.4, 0), 2);
      expect(roundTo(2.5, 0), 3);
      expect(roundTo(-2.5, 0), -3);
    });

    test('rounds to one decimal place', () {
      expect(roundTo(12.34, 1), 12.3);
      expect(roundTo(12.36, 1), 12.4);
    });

    test('zero stays zero', () {
      expect(roundTo(0, 2), 0);
    });

    test('never returns negative zero', () {
      expect(roundTo(-0.3, 0).isNegative, isFalse);
      expect(roundTo(-0.001, 2).isNegative, isFalse);
    });
  });

  test('Macros equality and addition', () {
    expect(
      const Macros(calories: 1, protein: 2, carbs: 3, fat: 4) ==
          const Macros(calories: 1, protein: 2, carbs: 3, fat: 4),
      isTrue,
    );
    expect(chicken + Macros.zero, chicken);
  });
}
