import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../core/metrics.dart';
import '../../core/meal_slot.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/form_widgets.dart';
import '../common/meal_slot_picker.dart';

/// Edits the name and macros of a one-off entry. Can also hand off to the
/// "Move to another day" picker.
class EditAdhocSheet extends ConsumerStatefulWidget {
  const EditAdhocSheet({super.key, required this.entry});

  final FoodLogEntry entry;

  @override
  ConsumerState<EditAdhocSheet> createState() => _EditAdhocSheetState();
}

class _EditAdhocSheetState extends ConsumerState<EditAdhocSheet> {
  late final _name = TextEditingController(text: widget.entry.name);
  late final _calories = TextEditingController(
    text: plainNumber(widget.entry.calories),
  );
  late final _protein = TextEditingController(
    text: plainNumber(widget.entry.protein),
  );
  late final _carbs = TextEditingController(
    text: plainNumber(widget.entry.carbs),
  );
  late final _fat = TextEditingController(text: plainNumber(widget.entry.fat));

  Map<String, String> _errors = const {};
  String? _saveError;
  bool _saving = false;
  late MealSlot? _slot = MealSlot.fromName(widget.entry.mealSlot);

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

  Future<void> _save() async {
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
          .updateAdhoc(
            widget.entry.id,
            name: _name.text,
            macros: Macros(
              calories: parseNumber(_calories.text)!,
              protein: parseNumber(_protein.text)!,
              carbs: parseNumber(_carbs.text)!,
              fat: parseNumber(_fat.text)!,
            ),
          );
      await _applySlot(ref, widget.entry, _slot);
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

  Future<void> _move() async {
    final moved = await showMoveEntryPicker(context, entry: widget.entry);
    if (moved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit one-off food',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('adhoc-edit-save'),
                    onPressed: _saving ? null : _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  CupertinoFormSection.insetGrouped(
                    children: [
                      formRow(
                        fieldKey: const Key('adhoc-edit-name'),
                        label: 'Name',
                        controller: _name,
                        error: _errors['name'],
                        numeric: false,
                      ),
                      formRow(
                        fieldKey: const Key('adhoc-edit-calories'),
                        label: 'Calories',
                        controller: _calories,
                        error: _errors['calories'],
                        suffix: 'kcal',
                      ),
                      formRow(
                        fieldKey: const Key('adhoc-edit-protein'),
                        label: 'Protein',
                        controller: _protein,
                        error: _errors['protein'],
                        suffix: 'g',
                      ),
                      formRow(
                        fieldKey: const Key('adhoc-edit-carbs'),
                        label: 'Carbs',
                        controller: _carbs,
                        error: _errors['carbs'],
                        suffix: 'g',
                      ),
                      formRow(
                        fieldKey: const Key('adhoc-edit-fat'),
                        label: 'Fat',
                        controller: _fat,
                        error: _errors['fat'],
                        suffix: 'g',
                      ),
                    ],
                  ),
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _saveError!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                  MealSlotFormSection(
                    value: _slot,
                    onChanged: (s) => setState(() => _slot = s),
                  ),
                  CupertinoButton(
                    key: const Key('adhoc-edit-move'),
                    onPressed: _move,
                    child: const Text('Move to another day'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a day with a date picker and moves [entry] there. Resolves to true
/// if the entry was moved.
Future<bool> showMoveEntryPicker(
  BuildContext context, {
  required FoodLogEntry entry,
}) async {
  final picked = await showCupertinoModalPopup<String>(
    context: context,
    builder: (_) => _MoveEntryPicker(entry: entry),
  );
  return picked != null;
}

class _MoveEntryPicker extends ConsumerStatefulWidget {
  const _MoveEntryPicker({required this.entry});

  final FoodLogEntry entry;

  @override
  ConsumerState<_MoveEntryPicker> createState() => _MoveEntryPickerState();
}

class _MoveEntryPickerState extends ConsumerState<_MoveEntryPicker> {
  late DateTime _picked = dateFromKey(widget.entry.logDate);
  bool _saving = false;
  String? _error;

  Future<void> _move() async {
    final key = dateKey(_picked);
    if (key == widget.entry.logDate) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(logRepositoryProvider).moveEntry(widget.entry.id, key);
      if (mounted) Navigator.of(context).pop(key);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not move: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Move to another day',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('move-entry-confirm'),
                    onPressed: _saving ? null : _move,
                    child: const Text('Move'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                key: const Key('move-entry-picker'),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _picked,
                onDateTimeChanged: (d) => _picked = d,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Writes [slot] to [entry] if it was changed from the stored one.
Future<void> _applySlot(
  WidgetRef ref,
  FoodLogEntry entry,
  MealSlot? slot,
) async {
  if (slot == null || slot.name == entry.mealSlot) return;
  await ref.read(logRepositoryProvider).updateMealSlot(entry.id, slot);
}
