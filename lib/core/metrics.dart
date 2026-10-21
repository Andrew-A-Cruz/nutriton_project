import 'nutrition_math.dart';

/// The tracked metrics. Used by onboarding, the Home summary and (later) the
/// Summary view. To add a metric, add it here and the compiler will point at
/// every `switch` that needs a new case.
enum Metric {
  calories('Calories', 'kcal'),
  protein('Protein', 'g'),
  carbs('Carbs', 'g'),
  fat('Fat', 'g');

  const Metric(this.label, this.unit);

  final String label;
  final String unit;
}

extension MetricAmounts on Metric {
  /// This metric's amount within [macros].
  double amountIn(Macros macros) => switch (this) {
    Metric.calories => macros.calories,
    Metric.protein => macros.protein,
    Metric.carbs => macros.carbs,
    Metric.fat => macros.fat,
  };

  /// Display text for [amount]: whole kcal, one decimal for grams.
  String format(double amount) => this == Metric.calories
      ? roundTo(amount, 0).toStringAsFixed(0)
      : roundTo(amount, 1).toStringAsFixed(1);
}

/// Plain text for a number without trailing zeros, e.g. 2000 -> '2000',
/// 1.5 -> '1.5'. Used to prefill input fields.
String plainNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

/// One line of macros for a food, meal or total, e.g.
/// '320 kcal · 12.5 g protein · 20.0 g carbs · 5.0 g fat'. Uses the same
/// rounding as every other display of a metric.
String formatMacroLine(Macros macros) =>
    '${Metric.calories.format(macros.calories)} kcal · '
    '${Metric.protein.format(macros.protein)} g protein · '
    '${Metric.carbs.format(macros.carbs)} g carbs · '
    '${Metric.fat.format(macros.fat)} g fat';
