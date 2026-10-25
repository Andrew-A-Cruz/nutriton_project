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

/// Calories and macronutrients, in kcal and grams. [fiber] and [sugar] are in
/// grams and [sodium] in milligrams. Those three are null when not recorded,
/// which is different from 0: a food with no sodium figure does not claim to
/// have none.
class Macros {
  const Macros({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber,
    this.sugar,
    this.sodium,
  });

  static const Macros zero = Macros();

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final double? sugar;
  final double? sodium;

  /// Adds two values. A nutrient that is null on both sides stays null; null
  /// on one side counts as 0.
  Macros operator +(Macros other) => Macros(
    calories: calories + other.calories,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
    fiber: _addOptional(fiber, other.fiber),
    sugar: _addOptional(sugar, other.sugar),
    sodium: _addOptional(sodium, other.sodium),
  );

  /// Scales every value. Null stays null.
  Macros times(double factor) => Macros(
    calories: calories * factor,
    protein: protein * factor,
    carbs: carbs * factor,
    fat: fat * factor,
    fiber: fiber == null ? null : fiber! * factor,
    sugar: sugar == null ? null : sugar! * factor,
    sodium: sodium == null ? null : sodium! * factor,
  );

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat &&
      other.fiber == fiber &&
      other.sugar == sugar &&
      other.sodium == sodium;

  @override
  int get hashCode =>
      Object.hash(calories, protein, carbs, fat, fiber, sugar, sodium);

  @override
  String toString() =>
      'Macros(calories: $calories, protein: $protein, carbs: $carbs, '
      'fat: $fat, fiber: $fiber, sugar: $sugar, sodium: $sodium)';
}

double? _addOptional(double? a, double? b) =>
    a == null && b == null ? null : (a ?? 0) + (b ?? 0);

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

/// How many of a set of entries have a value for one nutrient.
class Coverage {
  const Coverage({required this.recorded, required this.total});

  final int recorded;
  final int total;

  Coverage operator +(Coverage other) =>
      Coverage(recorded: recorded + other.recorded, total: total + other.total);

  /// True when some entries have a value and some do not. Only then is a
  /// coverage hint worth showing: all recorded needs none, and none recorded
  /// reads as a plain 0.
  bool get isPartial => recorded > 0 && recorded < total;
}

/// Coverage of the optional nutrient chosen by [pick] over [items].
Coverage coverageOf(Iterable<Macros> items, double? Function(Macros) pick) {
  var recorded = 0;
  var total = 0;
  for (final m in items) {
    total++;
    if (pick(m) != null) recorded++;
  }
  return Coverage(recorded: recorded, total: total);
}
