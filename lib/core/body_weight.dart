/// Body weight arithmetic: kg/lb conversion, formatting, input bounds and the
/// moving average. Pure Dart. Weights are stored in kilograms; the unit only
/// changes what is shown and typed.
library;

import 'date_key.dart';
import 'metrics.dart';
import 'nutrition_math.dart';

/// Kilograms in one avoirdupois pound.
const double kilogramsPerPound = 0.45359237;

/// Lowest and highest body weight accepted, in kilograms. Wide enough for any
/// real person, tight enough to catch a typo such as 800 or 0.8.
const double minBodyWeightKg = 20;
const double maxBodyWeightKg = 500;

/// Days in the moving-average window, counting the reading's own day.
const int movingAverageDays = 7;

/// The unit body weight is shown and typed in. Separate from the food
/// [WeightUnit].
enum BodyWeightUnit {
  kg,
  lb;

  double toKg(double value) => switch (this) {
    BodyWeightUnit.kg => value,
    BodyWeightUnit.lb => value * kilogramsPerPound,
  };

  double fromKg(double kg) => switch (this) {
    BodyWeightUnit.kg => kg,
    BodyWeightUnit.lb => kg / kilogramsPerPound,
  };
}

/// A weight in [unit] to one decimal place, e.g. '80.5 kg' or '177.5 lb'.
String formatBodyWeight(double kg, BodyWeightUnit unit) =>
    '${formatBodyWeightValue(kg, unit)} ${unit.name}';

/// The number alone, to one decimal place with no trailing zero.
String formatBodyWeightValue(double kg, BodyWeightUnit unit) =>
    plainNumber(roundTo(unit.fromKg(kg), 1));

/// The error to show for typed body weight [text] in [unit], or null if it is
/// a number in the accepted range.
String? validateBodyWeight(String text, BodyWeightUnit unit) {
  final value = double.tryParse(text.trim());
  if (value == null || !value.isFinite) return 'Enter a number';
  if (value <= 0) return 'Enter a number greater than 0';
  final kg = unit.toKg(value);
  if (kg < minBodyWeightKg || kg > maxBodyWeightKg) {
    final low = formatBodyWeightValue(minBodyWeightKg, unit);
    final high = formatBodyWeightValue(maxBodyWeightKg, unit);
    return 'Enter a weight between $low and $high ${unit.name}';
  }
  return null;
}

/// One reading: its day ('yyyy-MM-dd') and weight in kilograms.
typedef WeightReading = ({String date, double kg});

/// A moving average for each reading in [readings] (oldest first): the mean of
/// the readings dated within the last [windowDays] calendar days, ending on the
/// reading's own day.
///
/// The window is calendar days, not a count of readings, so a gap in
/// weighing does not stretch the average over old data: after a week with no
/// reading, the next point stands alone. Days without a reading are skipped,
/// not counted as zero, and with fewer than [windowDays] readings the mean is
/// over those available. The result has one point per reading, in order.
List<WeightReading> movingAverage(
  List<WeightReading> readings, {
  int windowDays = movingAverageDays,
}) {
  if (windowDays < 1) {
    throw ArgumentError.value(windowDays, 'windowDays', 'must be >= 1');
  }
  final result = <WeightReading>[];
  var first = 0; // index of the oldest reading still in the window
  var sum = 0.0;
  for (var i = 0; i < readings.length; i++) {
    sum += readings[i].kg;
    final windowStart = addDays(readings[i].date, -(windowDays - 1));
    while (readings[first].date.compareTo(windowStart) < 0) {
      sum -= readings[first].kg;
      first++;
    }
    result.add((date: readings[i].date, kg: sum / (i - first + 1)));
  }
  return result;
}
