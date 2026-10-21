import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/form_widgets.dart';

/// Logs a one-off food for [logDate]. Nothing is written to the catalog.
/// Pops to the root after logging.
class AdhocFoodForm extends ConsumerStatefulWidget {
  const AdhocFoodForm({super.key, required this.logDate});

  final String logDate;

  @override
  ConsumerState<AdhocFoodForm> createState() => _AdhocFoodFormState();
}

class _AdhocFoodFormState extends ConsumerState<AdhocFoodForm> {
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  Map<String, String> _errors = const {};
  String? _saveError;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _validate() {
    final checks = {
      'name': requiredName(_name.text),
      'calories': nonNegativeNumber(_calories.text),
      'protein': nonNegativeNumber(_protein.text),
      'carbs': nonNegativeNumber(_carbs.text),
      'fat': nonNegativeNumber(_fat.text),
    };
    return {
      for (final entry in checks.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<void> _log() async {
    final errors = _validate();
    setState(() {
      _errors = errors;
      _saveError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(logRepositoryProvider)
          .logAdhoc(
            logDate: widget.logDate,
            name: _name.text,
            macros: Macros(
              calories: parseNumber(_calories.text)!,
              protein: parseNumber(_protein.text)!,
              carbs: parseNumber(_carbs.text)!,
              fat: parseNumber(_fat.text)!,
            ),
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not log food: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        CupertinoFormSection.insetGrouped(
          header: const Text('ONE-OFF FOOD'),
          footer: const Text(
            'Logged for this day only. Not saved to the catalog.',
          ),
          children: [
            formRow(
              fieldKey: const Key('adhoc-name'),
              label: 'Name',
              controller: _name,
              error: _errors['name'],
              placeholder: 'e.g. Restaurant burrito',
              numeric: false,
            ),
            formRow(
              fieldKey: const Key('adhoc-calories'),
              label: 'Calories',
              controller: _calories,
              error: _errors['calories'],
              suffix: 'kcal',
            ),
            formRow(
              fieldKey: const Key('adhoc-protein'),
              label: 'Protein',
              controller: _protein,
              error: _errors['protein'],
              suffix: 'g',
            ),
            formRow(
              fieldKey: const Key('adhoc-carbs'),
              label: 'Carbs',
              controller: _carbs,
              error: _errors['carbs'],
              suffix: 'g',
            ),
            formRow(
              fieldKey: const Key('adhoc-fat'),
              label: 'Fat',
              controller: _fat,
              error: _errors['fat'],
              suffix: 'g',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: CupertinoButton.filled(
            key: const Key('adhoc-log'),
            onPressed: _saving ? null : _log,
            child: const Text('Log food'),
          ),
        ),
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _saveError!,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
      ],
    );
  }
}
