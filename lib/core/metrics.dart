import 'nutrition_math.dart';

/// The tracked metrics. Used by onboarding, the Home summary and (later) the
/// Summary view. To add a metric, add it here and the compiler will point at
/// every `switch` that needs a new case.
enum Metric {
  calories('Calories', 'kcal'),
  protein('Protein', 'g'),
  carbs('Carbs', 'g'),
  fat('Fat', 'g'),
  fiber('Fiber', 'g'),
  sugar('Sugar', 'g'),
  sodium('Sodium', 'mg');

  const Metric(this.label, this.unit);

  final String label;
  final String unit;

  /// The metrics whose values are optional on a food (null = not recorded).
  /// They can be tracked, but not chosen as the primary metric.
  static const List<Metric> optional = [fiber, sugar, sodium];

  bool get isOptional => optional.contains(this);
}

extension MetricAmounts on Metric {
  /// This metric's amount within [macros]; not recorded counts as 0.
  double amountIn(Macros macros) => recordedAmountIn(macros) ?? 0;

  /// This metric's amount within [macros], or null when it was not recorded.
  /// Only the optional metrics can be null.
  double? recordedAmountIn(Macros macros) => switch (this) {
    Metric.calories => macros.calories,
    Metric.protein => macros.protein,
    Metric.carbs => macros.carbs,
    Metric.fat => macros.fat,
    Metric.fiber => macros.fiber,
    Metric.sugar => macros.sugar,
    Metric.sodium => macros.sodium,
  };

  /// Display text for [amount]: whole kcal and mg, one decimal for grams.
  String format(double amount) => this == Metric.calories || unit == 'mg'
      ? roundTo(amount, 0).toStringAsFixed(0)
      : roundTo(amount, 1).toStringAsFixed(1);

  /// [format] plus the unit, e.g. '12.5 g' or '480 mg'.
  String formatWithUnit(double amount) => '${format(amount)} $unit';
}

/// The hint shown beside a total that only some entries contribute to, e.g.
/// 'Sodium recorded for 3 of 5 entries'. Null when [coverage] is complete or
/// empty, since then the total needs no caveat.
String? coverageText(Metric metric, Coverage coverage) => coverage.isPartial
    ? '${metric.label} recorded for ${coverage.recorded} of '
          '${coverage.total} entries'
    : null;

/// Plain text for a number without trailing zeros, e.g. 2000 -> '2000',
/// 1.5 -> '1.5'. Used to prefill input fields.
String plainNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

/// One line of macros for a food, meal or total, e.g.
/// '320 kcal · 12.5 g protein · 20.0 g carbs · 5.0 g fat'. Uses the same
/// rounding as every other display of a metric. The optional nutrients
/// (fiber, sugar, sodium) are added only when they are in [tracked] and have
/// a recorded value, so an untracked or unknown figure never takes up room.
String formatMacroLine(Macros macros, {Set<Metric> tracked = const {}}) {
  final parts = [
    '${Metric.calories.format(macros.calories)} kcal',
    '${Metric.protein.format(macros.protein)} g protein',
    '${Metric.carbs.format(macros.carbs)} g carbs',
    '${Metric.fat.format(macros.fat)} g fat',
    for (final m in Metric.optional)
      if (tracked.contains(m) && m.recordedAmountIn(macros) != null)
        '${m.formatWithUnit(m.recordedAmountIn(macros)!)} '
            '${m.label.toLowerCase()}',
  ];
  return parts.join(' · ');
}
