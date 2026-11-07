import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/meal_slot.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/error_feedback.dart';
import '../common/form_widgets.dart';
import '../common/meal_slot_picker.dart';

/// Name a quick add gets when none is typed.
const quickAddName = 'Quick add';

/// The fastest entry: a number of calories for [logDate], with optional
/// macros (blank is 0) and an optional label, e.g. a restaurant estimate.
/// Stored as a one-off entry; nothing goes to the catalog. Pops to the root
/// after logging.
class QuickAddForm extends ConsumerStatefulWidget {
  const QuickAddForm({super.key, required this.logDate});

  final String logDate;

  @override
  ConsumerState<QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<QuickAddForm> {
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _label = TextEditingController();

  Map<String, String> _errors = const {};
  String? _saveError;
  bool _saving = false;
  MealSlot _slot = MealSlot.forTime(DateTime.now());

  @override
  void dispose() {
    for (final c in [_calories, _protein, _carbs, _fat, _label]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Blank counts as 0 for the macros.
  static String? _optional(String text) =>
      text.trim().isEmpty ? null : nonNegativeNumber(text);

  static double _valueOf(TextEditingController c) => parseNumber(c.text) ?? 0;

  Map<String, String> _validate() {
    final label = _label.text.trim();
    final checks = {
      'calories': nonNegativeNumber(_calories.text),
      'protein': _optional(_protein.text),
      'carbs': _optional(_carbs.text),
      'fat': _optional(_fat.text),
      'label': label.length > maxNameLength
          ? 'Use at most $maxNameLength characters'
          : null,
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

    final label = _label.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(logRepositoryProvider)
          .logAdhoc(
            logDate: widget.logDate,
            name: label.isEmpty ? quickAddName : label,
            macros: Macros(
              calories: parseNumber(_calories.text)!,
              protein: _valueOf(_protein),
              carbs: _valueOf(_carbs),
              fat: _valueOf(_fat),
            ),
            mealSlot: _slot,
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = reportError(ref, e, stack, 'Could not log food');
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
          header: const Text('QUICK ADD'),
          footer: const Text(
            'Just the calories, e.g. an estimate. Macros left blank count '
            'as 0.',
          ),
          children: [
            formRow(
              fieldKey: const Key('quick-calories'),
              label: 'Calories',
              controller: _calories,
              error: _errors['calories'],
              suffix: 'kcal',
            ),
            formRow(
              fieldKey: const Key('quick-protein'),
              label: 'Protein',
              controller: _protein,
              error: _errors['protein'],
              placeholder: 'Optional',
              suffix: 'g',
            ),
            formRow(
              fieldKey: const Key('quick-carbs'),
              label: 'Carbs',
              controller: _carbs,
              error: _errors['carbs'],
              placeholder: 'Optional',
              suffix: 'g',
            ),
            formRow(
              fieldKey: const Key('quick-fat'),
              label: 'Fat',
              controller: _fat,
              error: _errors['fat'],
              placeholder: 'Optional',
              suffix: 'g',
            ),
            formRow(
              fieldKey: const Key('quick-label'),
              label: 'Label',
              controller: _label,
              error: _errors['label'],
              placeholder: quickAddName,
              numeric: false,
            ),
          ],
        ),
        MealSlotFormSection(
          value: _slot,
          onChanged: (s) => setState(() => _slot = s),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: CupertinoButton.filled(
            key: const Key('quick-log'),
            onPressed: _saving ? null : _log,
            child: const Text('Log'),
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
