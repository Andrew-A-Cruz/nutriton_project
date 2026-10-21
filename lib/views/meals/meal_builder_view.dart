import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';
import 'food_picker_page.dart';
import 'meal_items_editor.dart';

/// Creates or edits a meal template: a name and an ordered list of foods, each
/// with a weight. Pops after saving.
class MealBuilderView extends ConsumerStatefulWidget {
  const MealBuilderView({super.key, this.existing});

  final Meal? existing;

  @override
  ConsumerState<MealBuilderView> createState() => _MealBuilderViewState();
}

class _MealBuilderViewState extends ConsumerState<MealBuilderView> {
  late final TextEditingController _name;
  final List<MealDraftItem> _items = [];
  bool _loaded = false;
  String? _nameError;
  String? _itemsError;
  String? _saveError;
  bool _saving = false;

  /// Weights are typed in the user's display unit and stored in grams.
  WeightUnit get _unit => ref.read(preferencesProvider).displayUnit;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _loaded = widget.existing == null;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _addFood() async {
    final food = await Navigator.of(context).push<FoodItem>(
      CupertinoPageRoute<FoodItem>(builder: (_) => const FoodPickerPage()),
    );
    if (food == null || !mounted) return;
    setState(() {
      _items.add(
        MealDraftItem(food: food, grams: food.servingWeightG, unit: _unit),
      );
      _itemsError = null;
    });
  }

  Future<void> _save() async {
    final nameError = requiredName(_name.text);
    final itemsValid = validateDrafts(_items);
    setState(() {
      _nameError = nameError;
      _itemsError = _items.isEmpty ? 'Add at least one food' : null;
      _saveError = null;
    });
    if (nameError != null || !itemsValid) return;

    final catalog = ref.read(catalogRepositoryProvider);
    final inputs = draftInputs(_items);
    final existing = widget.existing;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        await catalog.createMeal(name: _name.text, items: inputs);
      } else {
        await catalog.updateMeal(existing.id, name: _name.text, items: inputs);
      }
      if (mounted) Navigator.of(context).pop();
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
    // Editing: copy the template's items into drafts once, when they arrive.
    if (!_loaded && existing != null) {
      final rows = ref.watch(mealItemsProvider(existing.id)).value;
      if (rows != null) {
        _loaded = true;
        for (final row in rows) {
          _items.add(
            MealDraftItem(food: row.food, grams: row.link.weightG, unit: _unit),
          );
        }
      }
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(existing == null ? 'New Meal' : 'Edit Meal'),
        trailing: CupertinoButton(
          key: const Key('meal-save'),
          padding: EdgeInsets.zero,
          onPressed: _saving || !_loaded ? null : _save,
          child: const Text('Save'),
        ),
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: !_loaded
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  CupertinoFormSection.insetGrouped(
                    header: const Text('MEAL'),
                    children: [
                      formRow(
                        fieldKey: const Key('meal-name'),
                        label: 'Name',
                        controller: _name,
                        error: _nameError,
                        placeholder: 'e.g. Chicken and rice',
                        numeric: false,
                      ),
                    ],
                  ),
                  MealItemsEditor(
                    items: _items,
                    unit: _unit,
                    onChanged: () => setState(() => _itemsError = null),
                    onAdd: _addFood,
                  ),
                  if (_itemsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FormFieldError(_itemsError),
                    ),
                  MealTotals(items: _items),
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _saveError!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
