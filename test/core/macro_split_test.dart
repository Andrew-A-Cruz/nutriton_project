import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/macro_split.dart';
import 'package:nutriton_project/core/nutrition_math.dart';

void main() {
  test('splits by calories per gram: 4, 4 and 9', () {
    // 100 g protein = 400, 100 g carbs = 400, 44.4 g fat = 400 kcal.
    final split = macroSplit(
      const Macros(calories: 1200, protein: 100, carbs: 100, fat: 400 / 9),
    );
    // A three-way tie: the extra point goes to the first.
    expect(split, (protein: 34, carbs: 33, fat: 33));
  });

  test('a typical day', () {
    final split = macroSplit(
      const Macros(calories: 2000, protein: 150, carbs: 200, fat: 67),
    );
    // 600 / 800 / 603 kcal of 2003.
    expect(split, (protein: 30, carbs: 40, fat: 30));
  });

  test('no macros means no split', () {
    expect(
      macroSplit(const Macros(calories: 500, protein: 0, carbs: 0, fat: 0)),
      isNull,
    );
  });

  test('rounded shares always add up to 100', () {
    expect(roundToHundred([33.3, 33.3, 33.4]), [33, 33, 34]);
    expect(roundToHundred([12.5, 12.5, 75]).fold<int>(0, (a, b) => a + b), 100);
    expect(roundToHundred([0.4, 0.4, 99.2]), [1, 0, 99]);
  });

  test('text for VoiceOver', () {
    expect(
      macroSplitText((protein: 30, carbs: 40, fat: 30)),
      'Protein 30%, carbs 40%, fat 30% of calories',
    );
  });
}
