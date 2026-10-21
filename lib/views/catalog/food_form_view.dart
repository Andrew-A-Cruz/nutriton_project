import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';

/// Creates or edits a catalog food. Pops with the saved [FoodItem], or with
/// null when cancelled, so the caller can act on it (Add Food logs it).
class FoodFormView extends ConsumerStatefulWidget {
  const FoodFormView({
    super.key,
    this.existing,
    this.offerLogAfterSave = false,
  });

  final FoodItem? existing;

  /// Labels the save button "Save & Log". The caller logs the popped food.
  final bool offerLogAfterSave;

  @override
  ConsumerState<FoodFormView> createState() => _FoodFormViewState();
}

class _FoodFormViewState extends ConsumerState<FoodFormView> {
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _weight;
  late WeightUnit _unit;
  late final WeightUnit _initialUnit;
  late final String _initialWeightText;

  Map<String, String> _errors = const {};
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _calories = TextEditingController(text: _macroText(existing?.calories));
    _protein = TextEditingController(text: _macroText(existing?.protein));
    _carbs = TextEditingController(text: _macroText(existing?.carbs));
    _fat = TextEditingController(text: _macroText(existing?.fat));
    _unit = existing == null
        ? ref.read(preferencesProvider).displayUnit
        : WeightUnit.values.asNameMap()[existing.displayUnit] ?? WeightUnit.g;
    _initialUnit = _unit;
    _initialWeightText = existing == null
        ? ''
        : _weightText(existing.servingWeightG, _unit);
    _weight = TextEditingController(text: _initialWeightText);
  }

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _macroText(double? value) =>
      value == null ? '' : plainNumber(value);

  static String _weightText(double grams, WeightUnit unit) =>
      plainNumber(roundTo(unit.fromGrams(grams), 2));

  /// True when the serving weight was left alone. Its stored grams are then
  /// kept exactly, instead of the rounded display value converted back.
  bool get _weightUnchanged =>
      widget.existing != null &&
      _unit == _initialUnit &&
      _weight.text == _initialWeightText;

  void _changeUnit(WeightUnit unit) {
    final typed = parseNumber(_weight.text);
    setState(() {
      if (typed != null && unit != _unit) {
        _weight.text = plainNumber(
          roundTo(unit.fromGrams(_unit.toGrams(typed)), 2),
        );
      }
      _unit = unit;
    });
  }

  Map<String, String> _validate() {
    final checks = {
      'name': requiredName(_name.text),
      'calories': nonNegativeNumber(_calories.text),
      'protein': nonNegativeNumber(_protein.text),
      'carbs': nonNegativeNumber(_carbs.text),
      'fat': nonNegativeNumber(_fat.text),
      'weight': _weightUnchanged ? null : positiveNumber(_weight.text),
    };
    return {
      for (final entry in checks.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<void> _save() async {
    final errors = _validate();
    setState(() {
      _errors = errors;
      _saveError = null;
    });
    if (errors.isNotEmpty) return;

    final existing = widget.existing;
    final grams = _weightUnchanged
        ? existing!.servingWeightG
        : _unit.toGrams(parseNumber(_weight.text)!);
    final perServing = Macros(
      calories: parseNumber(_calories.text)!,
      protein: parseNumber(_protein.text)!,
      carbs: parseNumber(_carbs.text)!,
      fat: parseNumber(_fat.text)!,
    );
    final catalog = ref.read(catalogRepositoryProvider);

    setState(() => _saving = true);
    try {
      final String id;
      if (existing == null) {
        id = await catalog.createFood(
          name: _name.text,
          perServing: perServing,
          servingWeightG: grams,
          displayUnit: _unit,
        );
      } else {
        id = existing.id;
        await catalog.updateFood(
          id,
          name: _name.text,
          perServing: perServing,
          servingWeightG: grams,
          displayUnit: _unit,
        );
      }
      final food = await catalog.findFood(id);
      if (mounted) Navigator.of(context).pop(food);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(existing == null ? 'New Food' : 'Edit Food'),
        trailing: CupertinoButton(
          key: const Key('food-save'),
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: Text(widget.offerLogAfterSave ? 'Save & Log' : 'Save'),
        ),
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('FOOD'),
              children: [
                formRow(
                  fieldKey: const Key('food-name'),
                  label: 'Name',
                  controller: _name,
                  error: _errors['name'],
                  placeholder: 'e.g. Chicken breast',
                  numeric: false,
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('PER SERVING'),
              footer: const Text('Macros for one serving, the size set below.'),
              children: [
                formRow(
                  fieldKey: const Key('food-calories'),
                  label: 'Calories',
                  controller: _calories,
                  error: _errors['calories'],
                  suffix: 'kcal',
                ),
                formRow(
                  fieldKey: const Key('food-protein'),
                  label: 'Protein',
                  controller: _protein,
                  error: _errors['protein'],
                  suffix: 'g',
                ),
                formRow(
                  fieldKey: const Key('food-carbs'),
                  label: 'Carbs',
                  controller: _carbs,
                  error: _errors['carbs'],
                  suffix: 'g',
                ),
                formRow(
                  fieldKey: const Key('food-fat'),
                  label: 'Fat',
                  controller: _fat,
                  error: _errors['fat'],
                  suffix: 'g',
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('SERVING SIZE'),
              footer: const Text(
                'Logging by weight converts to servings using this size.',
              ),
              children: [
                formRow(
                  fieldKey: const Key('food-serving-weight'),
                  label: 'Weight',
                  controller: _weight,
                  error: _errors['weight'],
                  placeholder: '100',
                  suffix: _unit.name,
                ),
                CupertinoFormRow(
                  prefix: const Text('Unit'),
                  child: CupertinoSlidingSegmentedControl<WeightUnit>(
                    key: const Key('food-unit'),
                    groupValue: _unit,
                    children: {
                      for (final u in WeightUnit.values) u: Text(u.name),
                    },
                    onValueChanged: (u) {
                      if (u != null) _changeUnit(u);
                    },
                  ),
                ),
              ],
            ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _saveError!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
