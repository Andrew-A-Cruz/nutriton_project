import 'package:flutter/cupertino.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';

/// A weight in the user's display unit, e.g. '100 g' or '3.5 oz'.
String formatWeight(double grams, WeightUnit unit) {
  final amount = roundTo(unit.fromGrams(grams), unit == WeightUnit.g ? 0 : 1);
  return '${plainNumber(amount)} ${unit.name}';
}

/// A validation message under a form field. Renders nothing when [message] is
/// null.
class FormFieldError extends StatelessWidget {
  const FormFieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message!,
        style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 13),
      ),
    );
  }
}

/// One labelled input in a [CupertinoFormSection], with its error underneath.
/// At large text sizes the label goes above the field, since beside it the
/// label leaves the field almost no width.
Widget formRow({
  required Key fieldKey,
  required String label,
  required TextEditingController controller,
  String? error,
  String? placeholder,
  String? suffix,
  bool numeric = true,
  ValueChanged<String>? onChanged,
}) {
  return Builder(
    builder: (context) {
      final stackLabel = MediaQuery.textScalerOf(context).scale(10) > 15;
      return CupertinoFormRow(
        prefix: stackLabel ? null : Text(label),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stackLabel)
              Align(alignment: Alignment.centerLeft, child: Text(label)),
            _formField(
              fieldKey: fieldKey,
              controller: controller,
              placeholder: placeholder,
              suffix: suffix,
              numeric: numeric,
              onChanged: onChanged,
            ),
            FormFieldError(error),
          ],
        ),
      );
    },
  );
}

CupertinoTextField _formField({
  required Key fieldKey,
  required TextEditingController controller,
  String? placeholder,
  String? suffix,
  bool numeric = true,
  ValueChanged<String>? onChanged,
}) {
  return CupertinoTextField(
    key: fieldKey,
    controller: controller,
    placeholder: placeholder,
    textAlign: TextAlign.end,
    onChanged: onChanged,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    suffix: suffix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(suffix),
          ),
  );
}

/// The optional nutrient inputs (fiber, sugar, sodium) of a food form. A field
/// shows only for a metric the user tracks and may be left empty, which stores
/// null (not recorded). A value for a metric that is not tracked is kept as it
/// was, so hiding a field never erases data.
class OptionalNutrientFields {
  OptionalNutrientFields({Macros? initial})
    : _initial = {
        for (final m in Metric.optional)
          m: initial == null ? null : m.recordedAmountIn(initial),
      },
      _controllers = {
        for (final m in Metric.optional)
          m: TextEditingController(text: _textOf(initial, m)),
      };

  static String _textOf(Macros? macros, Metric metric) {
    final value = macros == null ? null : metric.recordedAmountIn(macros);
    return value == null ? '' : plainNumber(value);
  }

  final Map<Metric, double?> _initial;
  final Map<Metric, TextEditingController> _controllers;

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
  }

  /// Fills the fields from [macros] (a lookup result); not recorded clears.
  void setFrom(Macros macros) {
    for (final m in Metric.optional) {
      _controllers[m]!.text = _textOf(macros, m);
    }
  }

  /// Errors for the tracked fields that hold something other than a
  /// non-negative number, keyed by [Metric.name].
  Map<String, String> validate(Set<Metric> tracked) => {
    for (final m in Metric.optional)
      if (tracked.contains(m) && _controllers[m]!.text.trim().isNotEmpty)
        if (nonNegativeNumber(_controllers[m]!.text) case final String error)
          m.name: error,
  };

  /// The value to store for [metric]: the typed number or null for a tracked
  /// field, the starting value for one that is not tracked. Call after
  /// [validate].
  double? valueFor(Metric metric, Set<Metric> tracked) {
    if (!tracked.contains(metric)) return _initial[metric];
    final text = _controllers[metric]!.text;
    return text.trim().isEmpty ? null : parseNumber(text);
  }

  /// [base] with the three optional nutrients filled in from the fields.
  Macros applyTo(Macros base, Set<Metric> tracked) => Macros(
    calories: base.calories,
    protein: base.protein,
    carbs: base.carbs,
    fat: base.fat,
    fiber: valueFor(Metric.fiber, tracked),
    sugar: valueFor(Metric.sugar, tracked),
    sodium: valueFor(Metric.sodium, tracked),
  );

  /// One optional row per tracked metric, keyed '[keyPrefix]-fiber' etc.
  List<Widget> rows({
    required String keyPrefix,
    required Set<Metric> tracked,
    required Map<String, String> errors,
  }) => [
    for (final m in Metric.optional)
      if (tracked.contains(m))
        formRow(
          fieldKey: Key('$keyPrefix-${m.name}'),
          label: m.label,
          controller: _controllers[m]!,
          error: errors[m.name],
          placeholder: 'Optional',
          suffix: m.unit,
        ),
  ];
}
