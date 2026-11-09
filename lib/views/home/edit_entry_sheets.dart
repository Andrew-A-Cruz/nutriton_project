import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../core/metrics.dart';
import '../../core/meal_slot.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/today_providers.dart';
import '../common/form_widgets.dart';
import '../common/meal_slot_picker.dart';
import '../common/error_feedback.dart';
import '../common/haptics.dart';
import 'date_header.dart' show dayLabel;
import 'undo_banner.dart';

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
  late final _extras = OptionalNutrientFields(
    initial: Macros(
      fiber: widget.entry.fiber,
      sugar: widget.entry.sugar,
      sodium: widget.entry.sodium,
    ),
  );

  Map<String, String> _errors = const {};
  String? _saveError;
  bool _saving = false;
  late MealSlot? _slot = MealSlot.fromName(widget.entry.mealSlot);

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    _extras.dispose();
    super.dispose();
  }

  Set<Metric> get _tracked => ref.read(preferencesProvider).trackedMetrics;

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
      ..._extras.validate(_tracked),
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
      final repo = ref.read(logRepositoryProvider);
      final before = await repo.snapshotEntry(widget.entry.id);
      await repo.updateAdhoc(
        widget.entry.id,
        name: _name.text,
        macros: _extras.applyTo(
          Macros(
            calories: parseNumber(_calories.text)!,
            protein: parseNumber(_protein.text)!,
            carbs: parseNumber(_carbs.text)!,
            fat: parseNumber(_fat.text)!,
          ),
          _tracked,
        ),
      );
      await _applySlot(ref, widget.entry, _slot);
      if (!mounted) return;
      if (before != null) {
        offerUndo(
          context,
          message: 'Entry updated',
          undo: () => repo.revertEntry(before),
        );
      }
      Navigator.of(context).pop();
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = reportError(ref, e, stack, 'Could not save');
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
    final tracked = ref.watch(preferencesProvider).trackedMetrics;
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
                      ..._extras.rows(
                        keyPrefix: 'adhoc-edit',
                        tracked: tracked,
                        errors: _errors,
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
    builder: (_) => _EntryDayPicker(entry: entry, copy: false),
  );
  return picked != null;
}

/// Asks for a day (tomorrow by default, for planning ahead) and logs a copy
/// of [entry] there, with an undo banner. Resolves to the day copied to, or
/// null if cancelled.
Future<String?> showCopyEntryPicker(
  BuildContext context, {
  required FoodLogEntry entry,
}) => showCupertinoModalPopup<String>(
  context: context,
  builder: (_) => _EntryDayPicker(entry: entry, copy: true),
);

/// The date picker behind "Move to another day" and "Copy to another day".
class _EntryDayPicker extends ConsumerStatefulWidget {
  const _EntryDayPicker({required this.entry, required this.copy});

  final FoodLogEntry entry;

  /// Copy the entry (a new entry on the picked day) instead of moving it.
  final bool copy;

  @override
  ConsumerState<_EntryDayPicker> createState() => _EntryDayPickerState();
}

class _EntryDayPickerState extends ConsumerState<_EntryDayPicker> {
  late DateTime _picked = dateFromKey(
    widget.copy ? _tomorrow : widget.entry.logDate,
  );
  bool _saving = false;
  String? _error;

  String get _tomorrow => addDays(ref.read(todayProvider), 1);

  Future<void> _confirm() => widget.copy ? _copy(dateKey(_picked)) : _move();

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
      final repo = ref.read(logRepositoryProvider);
      final from = widget.entry.logDate;
      await repo.moveEntry(widget.entry.id, key);
      if (!mounted) return;
      offerUndo(
        context,
        message: 'Moved to ${dayLabel(key, today: ref.read(todayProvider))}',
        undo: () => repo.moveEntry(widget.entry.id, from),
      );
      Navigator.of(context).pop(key);
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = reportError(ref, e, stack, 'Could not move');
        });
      }
    }
  }

  Future<void> _copy(String key) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(logRepositoryProvider);
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      final newId = await repo.duplicateEntry(widget.entry.id, key);
      Haptics.logged();
      showUndoBanner(
        overlay,
        message: 'Copied to ${dayLabel(key, today: ref.read(todayProvider))}',
        onUndo: () => repo.deleteEntry(newId),
      );
      if (mounted) Navigator.of(context).pop(key);
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = reportError(ref, e, stack, 'Could not copy');
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
                  Expanded(
                    child: Text(
                      widget.copy
                          ? 'Copy to another day'
                          : 'Move to another day',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: Key(
                      widget.copy ? 'copy-entry-confirm' : 'move-entry-confirm',
                    ),
                    onPressed: _saving ? null : _confirm,
                    child: Text(widget.copy ? 'Copy' : 'Move'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                key: Key(
                  widget.copy ? 'copy-entry-picker' : 'move-entry-picker',
                ),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _picked,
                onDateTimeChanged: (d) => _picked = d,
              ),
            ),
            if (widget.copy)
              CupertinoButton(
                key: const Key('copy-entry-tomorrow'),
                onPressed: _saving ? null : () => _copy(_tomorrow),
                child: const Text('Copy to tomorrow'),
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
