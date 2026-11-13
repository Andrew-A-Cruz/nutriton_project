/// Water arithmetic: glasses and milliliters, the daily total's bounds and
/// its display text. Pure Dart. Water is stored in milliliters; the unit only
/// changes what is shown and the size of one tap.
library;

import 'metrics.dart';
import 'nutrition_math.dart';

/// Milliliters in one glass.
const double glassMl = 250;

/// The most water one day can hold. Far above anything real, so a stuck
/// finger cannot run the total away.
const double maxWaterMl = 20000;

/// How water is shown on Home and Summary.
enum WaterUnit {
  glasses,
  ml;

  /// The label on the Settings control.
  String get label => switch (this) {
    WaterUnit.glasses => 'Glasses',
    WaterUnit.ml => 'ml',
  };
}

/// The water settings: whether the Home row shows, the display unit and an
/// optional daily goal in milliliters.
class WaterSettings {
  const WaterSettings({
    this.enabled = true,
    this.unit = WaterUnit.glasses,
    this.goalMl,
  });

  final bool enabled;
  final WaterUnit unit;

  /// Null = no goal.
  final double? goalMl;

  WaterSettings withEnabled(bool enabled) =>
      WaterSettings(enabled: enabled, unit: unit, goalMl: goalMl);

  WaterSettings withUnit(WaterUnit unit) =>
      WaterSettings(enabled: enabled, unit: unit, goalMl: goalMl);

  /// Null clears the goal.
  WaterSettings withGoalMl(double? goalMl) =>
      WaterSettings(enabled: enabled, unit: unit, goalMl: goalMl);

  @override
  bool operator ==(Object other) =>
      other is WaterSettings &&
      other.enabled == enabled &&
      other.unit == unit &&
      other.goalMl == goalMl;

  @override
  int get hashCode => Object.hash(enabled, unit, goalMl);

  @override
  String toString() =>
      'WaterSettings(enabled: $enabled, unit: $unit, goalMl: $goalMl)';
}

/// The day's total after adding [deltaMl] (negative takes away) to
/// [currentMl], kept between 0 and [maxWaterMl].
double adjustWater(double currentMl, double deltaMl) {
  final next = currentMl + deltaMl;
  if (next <= 0) return 0;
  return next > maxWaterMl ? maxWaterMl : next;
}

/// The number alone in [unit]: '3' or '2.5' glasses, '750' ml.
String formatWaterValue(double ml, WaterUnit unit) => switch (unit) {
  WaterUnit.glasses => plainNumber(roundTo(ml / glassMl, 1)),
  WaterUnit.ml => roundTo(ml, 0).toStringAsFixed(0),
};

/// An amount with its unit: '1 glass', '3 glasses', '750 ml'.
String formatWater(double ml, WaterUnit unit) => switch (unit) {
  WaterUnit.glasses =>
    '${formatWaterValue(ml, unit)} '
        '${roundTo(ml / glassMl, 1) == 1 ? 'glass' : 'glasses'}',
  WaterUnit.ml => '${formatWaterValue(ml, unit)} ml',
};

/// The Home row's text: '3 glasses', or '3 of 8 glasses' with a goal.
String waterProgressText(double ml, WaterSettings settings) {
  final goal = settings.goalMl;
  if (goal == null || goal <= 0) return formatWater(ml, settings.unit);
  return '${formatWaterValue(ml, settings.unit)} of '
      '${formatWater(goal, settings.unit)}';
}

/// The goal typed in [unit], in milliliters.
double waterGoalToMl(double value, WaterUnit unit) => switch (unit) {
  WaterUnit.glasses => value * glassMl,
  WaterUnit.ml => value,
};

/// The mean of the days' totals, or null when there are none. Days with no
/// water are left out, as Summary does for food.
double? averageWaterMl(Iterable<double> dayTotalsMl) {
  var sum = 0.0;
  var days = 0;
  for (final ml in dayTotalsMl) {
    sum += ml;
    days++;
  }
  return days == 0 ? null : sum / days;
}
