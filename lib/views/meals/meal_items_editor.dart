import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';

/// One food row while a meal is being edited. Owns its weight field, which
/// shows the weight in [unit] (the user's display unit).
class MealDraftItem {
  MealDraftItem({
    required this.food,
    required double grams,
    this.unit = WeightUnit.g,
  }) : _initialGrams = grams,
       _initialText = plainNumber(roundTo(unit.fromGrams(grams), 2)) {
    weight = TextEditingController(text: _initialText);
  }

  final FoodItem food;
  final WeightUnit unit;
  late final TextEditingController weight;
  final double _initialGrams;
  final String _initialText;

  /// Validation message from the last check, shown under the row.
  String? error;

  /// The typed weight in grams, or null when it is not a number. An untouched
  /// field keeps its exact starting grams, so a rounded ounce value never
  /// drifts the stored weight.
  double? get grams {
    if (weight.text == _initialText) return _initialGrams;
    final typed = parseNumber(weight.text);
    return typed == null ? null : unit.toGrams(typed);
  }

  void dispose() => weight.dispose();
}

/// Macros of the rows whose weights parse. Rows with bad input are skipped, so
/// the running total still updates while the user types.
Macros draftTotals(Iterable<MealDraftItem> items) => sumMacros(
  items
      .where((i) => i.grams != null && i.grams! >= 0)
      .map((i) => CatalogRepository.macrosForWeight(i.food, i.grams!)),
);

/// Checks every row and records its error. Returns true when all are valid and
/// at least one row exists.
bool validateDrafts(List<MealDraftItem> items) {
  var valid = items.isNotEmpty;
  for (final item in items) {
    item.error = positiveNumber(item.weight.text);
    if (item.error != null) valid = false;
  }
  return valid;
}

/// The repository input for valid [items], in order. Call [validateDrafts]
/// first.
List<MealItemInput> draftInputs(List<MealDraftItem> items) => [
  for (final item in items)
    MealItemInput(foodItemId: item.food.id, weightG: item.grams!),
];

/// The foods in a meal, each with a weight field, reorder and remove buttons,
/// and an add row. Edits [items] in place and calls [onChanged] after each
/// change, so the parent can rebuild its totals.
class MealItemsEditor extends StatelessWidget {
  const MealItemsEditor({
    super.key,
    required this.items,
    required this.onChanged,
    required this.onAdd,
    this.unit = WeightUnit.g,
  });

  final List<MealDraftItem> items;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  /// The unit the weight fields are typed in.
  final WeightUnit unit;

  void _move(int from, int delta) {
    final to = from + delta;
    if (to < 0 || to >= items.length) return;
    final item = items.removeAt(from);
    items.insert(to, item);
    onChanged();
  }

  void _remove(int index) {
    items.removeAt(index).dispose();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoFormSection.insetGrouped(
      header: const Text('FOODS'),
      footer: Text(
        'Weights are in ${unit == WeightUnit.g ? 'grams' : 'ounces'}.',
      ),
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            key: ValueKey(items[i]),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].food.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: CupertinoTextField(
                        key: Key('item-weight-$i'),
                        controller: items[i].weight,
                        textAlign: TextAlign.end,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        suffix: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(items[i].unit.name),
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ],
                ),
                FormFieldError(items[i].error),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      key: Key('item-up-$i'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: i > 0 ? () => _move(i, -1) : null,
                      child: const Icon(CupertinoIcons.arrow_up),
                    ),
                    CupertinoButton(
                      key: Key('item-down-$i'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: i < items.length - 1
                          ? () => _move(i, 1)
                          : null,
                      child: const Icon(CupertinoIcons.arrow_down),
                    ),
                    CupertinoButton(
                      key: Key('item-remove-$i'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => _remove(i),
                      child: const Icon(
                        CupertinoIcons.minus_circle,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        CupertinoListTile(
          key: const Key('add-meal-item'),
          leading: const Icon(CupertinoIcons.add_circled),
          title: const Text('Add food'),
          onTap: onAdd,
        ),
      ],
    );
  }
}

/// Running totals for the rows in a meal.
class MealTotals extends ConsumerWidget {
  const MealTotals({super.key, required this.items});

  final List<MealDraftItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = draftTotals(items);
    return CupertinoFormSection.insetGrouped(
      header: const Text('TOTAL'),
      children: [
        CupertinoListTile(
          title: Text(
            '${Metric.calories.format(totals.calories)} kcal',
            key: const Key('meal-total-calories'),
          ),
          subtitle: Text(
            formatMacroLine(
              totals,
              tracked: ref.watch(preferencesProvider).trackedMetrics,
            ),
          ),
        ),
      ],
    );
  }
}
