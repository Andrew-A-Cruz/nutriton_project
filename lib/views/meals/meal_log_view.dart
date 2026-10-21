import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';
import '../home/date_header.dart';
import 'food_picker_page.dart';
import 'meal_items_editor.dart';

/// Logs a meal for [logDate]. The foods start as the template's, and can be
/// added, removed or re-weighed for this one entry. The template only changes
/// when "Update meal template" is switched on. Pops to the root after logging.
class MealLogView extends ConsumerStatefulWidget {
  const MealLogView({super.key, required this.meal, required this.logDate});

  final Meal meal;
  final String logDate;

  @override
  ConsumerState<MealLogView> createState() => _MealLogViewState();
}

class _MealLogViewState extends ConsumerState<MealLogView> {
  final List<MealDraftItem> _items = [];
  bool _loaded = false;
  bool _updateTemplate = false;
  String? _itemsError;
  String? _saveError;
  bool _saving = false;

  /// Weights are typed in the user's display unit and stored in grams.
  WeightUnit get _unit => ref.read(preferencesProvider).displayUnit;

  @override
  void dispose() {
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

  Future<void> _log() async {
    final valid = validateDrafts(_items);
    setState(() {
      _itemsError = _items.isEmpty ? 'Add at least one food' : null;
      _saveError = null;
    });
    if (!valid) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(logRepositoryProvider)
          .logMeal(
            logDate: widget.logDate,
            meal: widget.meal,
            items: draftInputs(_items),
            updateTemplate: _updateTemplate,
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not log meal: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Copy the template into editable drafts once, when its items arrive.
    if (!_loaded) {
      final rows = ref.watch(mealItemsProvider(widget.meal.id)).value;
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
        middle: Text(widget.meal.name),
        trailing: CupertinoButton(
          key: const Key('meal-log-confirm'),
          padding: EdgeInsets.zero,
          onPressed: _saving || !_loaded ? null : _log,
          child: const Text('Log'),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Logging to ${dayLabel(widget.logDate, today: todayKey())}',
                      key: const Key('meal-log-date'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
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
                  CupertinoFormSection.insetGrouped(
                    footer: const Text(
                      'Off: only this log entry changes. '
                      'On: the meal itself is changed to match.',
                    ),
                    children: [
                      CupertinoListTile(
                        title: const Text('Update meal template'),
                        trailing: CupertinoSwitch(
                          key: const Key('update-template-toggle'),
                          value: _updateTemplate,
                          onChanged: (on) =>
                              setState(() => _updateTemplate = on),
                        ),
                      ),
                    ],
                  ),
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
