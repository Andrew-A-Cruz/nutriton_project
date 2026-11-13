import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../core/water.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';

/// Settings section for water: whether the row shows on Today, glasses or
/// ml, and an optional daily goal. Changes save at once, like the reminders.
class WaterSection extends ConsumerStatefulWidget {
  const WaterSection({super.key});

  @override
  ConsumerState<WaterSection> createState() => _WaterSectionState();
}

class _WaterSectionState extends ConsumerState<WaterSection> {
  late final _goal = TextEditingController(
    text: _goalText(ref.read(preferencesProvider).water),
  );
  String? _error;

  static String _goalText(WaterSettings water) {
    final goal = water.goalMl;
    if (goal == null) return '';
    return switch (water.unit) {
      WaterUnit.glasses => plainNumber(roundTo(goal / glassMl, 1)),
      WaterUnit.ml => plainNumber(roundTo(goal, 0)),
    };
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save(WaterSettings water) {
    final settings = ref.read(preferencesProvider);
    return ref
        .read(preferencesProvider.notifier)
        .save(settings.copyWith(water: water));
  }

  void _goalChanged(String text) {
    final water = ref.read(preferencesProvider).water;
    if (text.trim().isEmpty) {
      setState(() => _error = null);
      _save(water.withGoalMl(null));
      return;
    }
    final value = parseNumber(text);
    final ml = value == null ? null : waterGoalToMl(value, water.unit);
    if (ml == null || ml <= 0 || ml > maxWaterMl) {
      setState(() => _error = 'Enter a number greater than 0');
      return;
    }
    setState(() => _error = null);
    _save(water.withGoalMl(ml));
  }

  Future<void> _unitChanged(WaterUnit unit) async {
    final water = ref.read(preferencesProvider).water.withUnit(unit);
    await _save(water);
    // The goal is kept in ml, so the field is rewritten in the new unit.
    _goal.text = _goalText(water);
    if (mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final water = ref.watch(preferencesProvider.select((s) => s.water));
    return CupertinoFormSection.insetGrouped(
      header: const Text('WATER'),
      footer: Text(
        'A row on Today with − and + for one glass '
        '(${glassMl.round()} ml). Leave the goal blank for none.',
      ),
      children: [
        CupertinoListTile(
          title: const Text('Track Water'),
          trailing: CupertinoSwitch(
            key: const Key('water-enabled'),
            value: water.enabled,
            onChanged: (on) => _save(water.withEnabled(on)),
          ),
        ),
        if (water.enabled) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<WaterUnit>(
                key: const Key('water-unit'),
                groupValue: water.unit,
                children: {for (final u in WaterUnit.values) u: Text(u.label)},
                onValueChanged: (u) {
                  if (u != null) _unitChanged(u);
                },
              ),
            ),
          ),
          formRow(
            fieldKey: const Key('water-goal'),
            label: 'Daily Goal',
            controller: _goal,
            error: _error,
            placeholder: 'No goal',
            suffix: water.unit == WaterUnit.glasses ? 'glasses' : 'ml',
            onChanged: _goalChanged,
          ),
        ],
      ],
    );
  }
}
