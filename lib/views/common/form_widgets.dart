import 'package:flutter/cupertino.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';

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
CupertinoFormRow formRow({
  required Key fieldKey,
  required String label,
  required TextEditingController controller,
  String? error,
  String? placeholder,
  String? suffix,
  bool numeric = true,
  ValueChanged<String>? onChanged,
}) {
  return CupertinoFormRow(
    prefix: Text(label),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoTextField(
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
        ),
        FormFieldError(error),
      ],
    ),
  );
}
