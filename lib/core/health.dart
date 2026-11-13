/// What the app sends to and reads from the phone's health store. Pure Dart:
/// the `health` package types stay in `data/health/`.
library;

import 'body_weight.dart';
import 'date_key.dart';
import 'nutrition_math.dart';

/// The nutrients written to the health store.
enum HealthNutrient { energy, protein, carbs, fat, fiber, sugar, sodium }

/// The units a sample is written in.
enum HealthUnit { kilocalorie, gram }

/// One value to write: a whole day's total of one [type].
typedef NutritionSample = ({
  HealthNutrient type,
  double value,
  HealthUnit unit,
});

/// A group of data the user can switch on separately in Settings. Each is
/// authorized on its own, only when first turned on.
enum HealthGroup {
  /// Writes the day's nutrition totals.
  nutrition,

  /// Reads body weight.
  weight,

  /// Reads the step count.
  steps,
}

/// How many days back (counting today) are written when writing is turned on.
/// Older days are left alone, so enabling stays fast on a long history.
const healthBackfillDays = 30;

/// How many days back (counting today) body weight is read.
const healthWeightImportDays = 90;

/// The samples to write for a day whose entries add up to [totals]: one per
/// nutrient, in [HealthNutrient] order.
///
/// A nutrient that was never recorded (null fiber, sugar or sodium) is left
/// out, as is any value that is 0 or less, so a day with nothing logged gives
/// an empty list. Sodium is kept in milligrams in the app, but HealthKit's
/// units for it are grams, so it is divided by 1000.
List<NutritionSample> nutritionSamples(Macros totals) {
  final all = <NutritionSample>[
    (
      type: HealthNutrient.energy,
      value: totals.calories,
      unit: HealthUnit.kilocalorie,
    ),
    (
      type: HealthNutrient.protein,
      value: totals.protein,
      unit: HealthUnit.gram,
    ),
    (type: HealthNutrient.carbs, value: totals.carbs, unit: HealthUnit.gram),
    (type: HealthNutrient.fat, value: totals.fat, unit: HealthUnit.gram),
    if (totals.fiber != null)
      (type: HealthNutrient.fiber, value: totals.fiber!, unit: HealthUnit.gram),
    if (totals.sugar != null)
      (type: HealthNutrient.sugar, value: totals.sugar!, unit: HealthUnit.gram),
    if (totals.sodium != null)
      (
        type: HealthNutrient.sodium,
        value: totals.sodium! / 1000,
        unit: HealthUnit.gram,
      ),
  ];
  return [
    for (final s in all)
      if (s.value.isFinite && s.value > 0) s,
  ];
}

/// One reading from the health store: when it was taken and the weight in kg.
typedef TimedWeight = ({DateTime when, double kg});

/// One reading per local day from [readings]: the latest of the day, and only
/// those inside the accepted body weight range. Oldest day first.
List<WeightReading> dailyWeights(Iterable<TimedWeight> readings) {
  final latest = <String, TimedWeight>{};
  for (final r in readings) {
    if (!r.kg.isFinite || r.kg < minBodyWeightKg || r.kg > maxBodyWeightKg) {
      continue;
    }
    final key = dateKey(r.when);
    final seen = latest[key];
    if (seen == null || r.when.isAfter(seen.when)) latest[key] = r;
  }
  final keys = latest.keys.toList()..sort();
  return [for (final k in keys) (date: k, kg: latest[k]!.kg)];
}

/// One stretch of steps from the health store, already de-duplicated across
/// devices: when it started and how many steps.
typedef TimedSteps = ({DateTime from, double steps});

/// Total steps per local day from [stretches], keyed 'yyyy-MM-dd'. A stretch
/// counts on the day it starts; ones that are not a positive number are
/// skipped. Totals are rounded to whole steps.
Map<String, int> dailySteps(Iterable<TimedSteps> stretches) {
  final totals = <String, double>{};
  for (final s in stretches) {
    if (!s.steps.isFinite || s.steps <= 0) continue;
    final key = dateKey(s.from);
    totals[key] = (totals[key] ?? 0) + s.steps;
  }
  return {for (final e in totals.entries) e.key: e.value.round()};
}

/// The highest daily step goal accepted.
const maxStepsGoal = 100000;

/// "8,214" or "8,214 / 10,000" with a goal. [format] groups the thousands.
String stepsProgressText(
  int steps,
  int? goal, {
  required String Function(int) format,
}) => goal == null || goal <= 0
    ? format(steps)
    : '${format(steps)} / ${format(goal)}';

/// The average of the days in [days] that have steps, rounded, or null when
/// none do.
int? averageDailySteps(Map<String, int> days) {
  final counted = [
    for (final v in days.values)
      if (v > 0) v,
  ];
  if (counted.isEmpty) return null;
  return (counted.reduce((a, b) => a + b) / counted.length).round();
}
