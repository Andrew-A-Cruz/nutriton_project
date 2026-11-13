import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health.dart';
import '../../core/validation.dart';
import '../../providers/health_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/error_feedback.dart';
import '../common/form_widgets.dart';
import '../common/pro_gate.dart';

/// Settings section for Apple Health, off by default and shown only where a
/// health store exists (iOS). Each switch asks for permission for its own data
/// when first turned on, and a refusal leaves it off. Changes save at once.
/// Apple Health is a Pro feature: without Pro each switch is a lock badge.
class AppleHealthSection extends ConsumerStatefulWidget {
  const AppleHealthSection({super.key});

  @override
  ConsumerState<AppleHealthSection> createState() => _AppleHealthSectionState();
}

class _AppleHealthSectionState extends ConsumerState<AppleHealthSection> {
  String? _denied;
  late final TextEditingController _stepsGoal;
  String? _stepsGoalError;

  @override
  void initState() {
    super.initState();
    _stepsGoal = TextEditingController(
      text: ref.read(stepsGoalProvider)?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _stepsGoal.dispose();
    super.dispose();
  }

  void _stepsGoalChanged(String text) {
    final notifier = ref.read(stepsGoalProvider.notifier);
    if (text.trim().isEmpty) {
      setState(() => _stepsGoalError = null);
      notifier.set(null);
      return;
    }
    final value = parseNumber(text);
    if (value == null ||
        value < 1 ||
        value > maxStepsGoal ||
        value != value.roundToDouble()) {
      setState(
        () => _stepsGoalError = 'Enter a whole number from 1 to $maxStepsGoal',
      );
      return;
    }
    setState(() => _stepsGoalError = null);
    notifier.set(value.round());
  }

  Future<void> _toggle(HealthGroup group, bool on) async {
    if (on) {
      var granted = false;
      try {
        granted = await ref
            .read(healthServiceProvider)
            .requestAuthorization(group);
      } catch (e, stack) {
        // Treated like a refusal: the switch stays off.
        reportError(ref, e, stack, 'Could not ask Apple Health for access');
      }
      if (!mounted) return;
      if (!granted) {
        setState(
          () => _denied =
              'Logbite does not have access to Apple Health. Allow it in '
              'the Health app, under Sharing, then try again.',
        );
        return;
      }
    }
    setState(() => _denied = null);
    if (group == HealthGroup.steps) {
      await ref.read(showStepsProvider.notifier).set(on);
      return;
    }
    final settings = ref.read(preferencesProvider);
    await ref.read(preferencesProvider.notifier).save(switch (group) {
      HealthGroup.nutrition => settings.copyWith(healthWriteNutrition: on),
      HealthGroup.weight => settings.copyWith(healthReadWeight: on),
      HealthGroup.steps => settings,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(healthSupportedProvider)) return const SizedBox.shrink();
    final write = ref.watch(
      preferencesProvider.select((s) => s.healthWriteNutrition),
    );
    final read = ref.watch(
      preferencesProvider.select((s) => s.healthReadWeight),
    );
    final steps = ref.watch(showStepsProvider);
    return CupertinoFormSection.insetGrouped(
      header: const Text('APPLE HEALTH'),
      footer: Text(
        _denied ??
            'Write Nutrition sends each day\'s energy, protein, carbs, fat '
                'and, when recorded, fiber, sugar and sodium, for the last '
                '$healthBackfillDays days and onwards. Read Body Weight fills '
                'days where you have not entered a weight. Show Steps puts '
                'the day\'s steps on Today; they are read from Health each '
                'time and are not saved in Logbite or its backups.',
        style: _denied == null
            ? null
            : const TextStyle(color: CupertinoColors.systemRed),
      ),
      children: [
        CupertinoListTile(
          title: const Text('Write Nutrition'),
          trailing: ProGate(
            child: CupertinoSwitch(
              key: const Key('health-write-switch'),
              value: write,
              onChanged: (on) => _toggle(HealthGroup.nutrition, on),
            ),
          ),
        ),
        CupertinoListTile(
          title: const Text('Read Body Weight'),
          trailing: ProGate(
            child: CupertinoSwitch(
              key: const Key('health-read-switch'),
              value: read,
              onChanged: (on) => _toggle(HealthGroup.weight, on),
            ),
          ),
        ),
        CupertinoListTile(
          title: const Text('Show Steps'),
          trailing: ProGate(
            child: CupertinoSwitch(
              key: const Key('health-steps-switch'),
              value: steps,
              onChanged: (on) => _toggle(HealthGroup.steps, on),
            ),
          ),
        ),
        if (steps && ref.watch(stepsEnabledProvider))
          formRow(
            fieldKey: const Key('steps-goal'),
            label: 'Daily Step Goal',
            controller: _stepsGoal,
            error: _stepsGoalError,
            placeholder: 'No goal',
            suffix: 'steps',
            onChanged: _stepsGoalChanged,
          ),
      ],
    );
  }
}
