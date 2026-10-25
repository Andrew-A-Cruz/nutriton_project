import 'package:flutter/cupertino.dart';

import '../../core/meal_slot.dart';

/// Picks a [MealSlot]. A segmented control of the four slots; with large text,
/// on a narrow screen or when [compact] is set (inside a dialog) it becomes
/// two rows of two, so labels never overflow or shrink. [value] may be null
/// (nothing selected).
///
/// This avoids a `LayoutBuilder` on purpose: alert dialogs ask for intrinsic
/// sizes, which a `LayoutBuilder` cannot give.
class MealSlotPicker extends StatelessWidget {
  const MealSlotPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final MealSlot? value;
  final ValueChanged<MealSlot> onChanged;
  final bool compact;

  Widget _control(Key key, List<MealSlot> slots) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<MealSlot>(
        key: key,
        groupValue: slots.contains(value) ? value : null,
        children: {for (final s in slots) s: Text(s.label)},
        onValueChanged: (slot) {
          if (slot != null) onChanged(slot);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    if (!large && !narrow && !compact) {
      return _control(const Key('meal-slot-picker'), MealSlot.values);
    }
    return Column(
      key: const Key('meal-slot-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _control(const Key('meal-slot-row-1'), [
          MealSlot.breakfast,
          MealSlot.lunch,
        ]),
        const SizedBox(height: 8),
        _control(const Key('meal-slot-row-2'), [
          MealSlot.dinner,
          MealSlot.snack,
        ]),
      ],
    );
  }
}

/// A [MealSlotPicker] in its own form section, for logging screens.
class MealSlotFormSection extends StatelessWidget {
  const MealSlotFormSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MealSlot? value;
  final ValueChanged<MealSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoFormSection.insetGrouped(
      header: const Text('MEAL'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: MealSlotPicker(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
