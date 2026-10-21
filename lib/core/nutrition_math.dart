/// Pure nutrition arithmetic. No Flutter or drift imports, so it is trivially
/// testable. All weights are stored internally in grams.
library;

/// Grams in one avoirdupois ounce.
const double gramsPerOunce = 28.3495;

enum WeightUnit {
  g,
  oz;

  double toGrams(double value) => switch (this) {
    WeightUnit.g => value,
    WeightUnit.oz => value * gramsPerOunce,
  };

  double fromGrams(double grams) => switch (this) {
    WeightUnit.g => grams,
    WeightUnit.oz => grams / gramsPerOunce,
  };
}

/// Calories and macronutrients, in kcal and grams.
class Macros {
  const Macros({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  static const Macros zero = Macros();

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  Macros operator +(Macros other) => Macros(
    calories: calories + other.calories,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
  );

  Macros times(double factor) => Macros(
    calories: calories * factor,
    protein: protein * factor,
    carbs: carbs * factor,
    fat: fat * factor,
  );

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(calories, protein, carbs, fat);

  @override
  String toString() =>
      'Macros(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat)';
}

/// Macros for [servings] of a food whose [perServing] values are known.
Macros scaleByServings(Macros perServing, double servings) {
  if (servings < 0) {
    throw ArgumentError.value(servings, 'servings', 'must be >= 0');
  }
  return perServing.times(servings);
}

/// Macros for [weightG] grams of a food defined per [servingWeightG] grams.
///
/// Example: a food defined per 100 g, eaten at 4 oz (113.398 g), yields
/// `item_ratio` 1.13398, not 0.04.
Macros scaleByWeight(
  Macros perServing, {
  required double servingWeightG,
  required double weightG,
}) {
  if (servingWeightG <= 0) {
    throw ArgumentError.value(servingWeightG, 'servingWeightG', 'must be > 0');
  }
  if (weightG < 0) {
    throw ArgumentError.value(weightG, 'weightG', 'must be >= 0');
  }
  return perServing.times(weightG / servingWeightG);
}

/// Servings equal to [weightG] grams of a food whose serving is
/// [servingWeightG] grams. Logging by weight converts through this, then logs
/// by servings.
double servingsForWeight({
  required double weightG,
  required double servingWeightG,
}) {
  if (servingWeightG <= 0) {
    throw ArgumentError.value(servingWeightG, 'servingWeightG', 'must be > 0');
  }
  if (weightG < 0) {
    throw ArgumentError.value(weightG, 'weightG', 'must be >= 0');
  }
  return weightG / servingWeightG;
}

/// Sum of several macro values (e.g. the items in a meal).
Macros sumMacros(Iterable<Macros> items) =>
    items.fold(Macros.zero, (total, m) => total + m);

/// Rounds [value] to [places] decimal places. Halves round away from zero.
double roundTo(double value, int places) {
  assert(places >= 0);
  var factor = 1.0;
  for (var i = 0; i < places; i++) {
    factor *= 10;
  }
  final rounded = (value * factor).roundToDouble() / factor;
  // Turns -0.0 into 0 so it never displays as "-0".
  return rounded == 0 ? 0 : rounded;
}
