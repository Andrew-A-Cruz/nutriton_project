import 'package:flutter/cupertino.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/preferences/user_preferences.dart';

/// Form for the primary metric, tracked metrics, daily goals and units. Used by
/// onboarding now and by Settings in M8, so it has no storage code of its own.
class PreferencesForm extends StatefulWidget {
  const PreferencesForm({
    super.key,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  final UserSettings initial;
  final String submitLabel;

  /// Called with the validated settings. `onboardingComplete` is copied from
  /// [initial]; the caller decides whether to change it.
  final ValueChanged<UserSettings> onSubmit;

  @override
  State<PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends State<PreferencesForm> {
  late Metric _primary = widget.initial.primaryMetric;
  late final Set<Metric> _tracked = {...widget.initial.trackedMetrics};
  late WeightUnit _unit = widget.initial.displayUnit;
  late final Map<Metric, TextEditingController> _goals = {
    for (final m in Metric.values)
      m: TextEditingController(
        text: widget.initial.goalFor(m) == null
            ? ''
            : plainNumber(widget.initial.goalFor(m)!),
      ),
  };
  final Map<Metric, String> _errors = {};

  @override
  void dispose() {
    for (final controller in _goals.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final errors = <Metric, String>{};
    final goals = <Metric, double>{};
    for (final m in Metric.values) {
      final text = _goals[m]!.text.trim();
      final tracked = _tracked.contains(m);
      if (text.isEmpty) {
        if (m == _primary) errors[m] = 'Enter a daily goal for ${m.label}';
        continue;
      }
      final value = parseNumber(text);
      if (value == null || value <= 0) {
        if (tracked) errors[m] = 'Enter a number greater than 0';
        continue;
      }
      goals[m] = value;
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty) return;

    widget.onSubmit(
      UserSettings(
        onboardingComplete: widget.initial.onboardingComplete,
        primaryMetric: _primary,
        trackedMetrics: _tracked,
        goals: goals,
        displayUnit: _unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Dragging the list hides the keyboard, so the goal fields never trap it.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        CupertinoFormSection.insetGrouped(
          header: const Text('PRIMARY METRIC'),
          footer: const Text('Shown large on the Today screen.'),
          children: [
            for (final m in Metric.values)
              CupertinoListTile(
                key: Key('primary-${m.name}'),
                title: Text(m.label),
                trailing: m == _primary
                    ? const Icon(CupertinoIcons.check_mark)
                    : null,
                onTap: () => setState(() {
                  _primary = m;
                  _tracked.add(m);
                }),
              ),
          ],
        ),
        CupertinoFormSection.insetGrouped(
          header: const Text('TRACK'),
          footer: const Text('The primary metric is always tracked.'),
          children: [
            for (final m in Metric.values)
              CupertinoListTile(
                title: Text(m.label),
                trailing: CupertinoSwitch(
                  key: Key('track-${m.name}'),
                  value: _tracked.contains(m),
                  onChanged: m == _primary
                      ? null
                      : (on) => setState(() {
                          if (on) {
                            _tracked.add(m);
                          } else {
                            _tracked.remove(m);
                          }
                        }),
                ),
              ),
          ],
        ),
        CupertinoFormSection.insetGrouped(
          header: const Text('DAILY GOALS'),
          footer: const Text('Leave blank for no goal.'),
          children: [
            for (final m in Metric.values.where(_tracked.contains))
              CupertinoFormRow(
                prefix: Text(m.label),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CupertinoTextField(
                      key: Key('goal-${m.name}'),
                      controller: _goals[m],
                      placeholder: 'No goal',
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(m.unit),
                      ),
                    ),
                    if (_errors[m] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _errors[m]!,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        CupertinoFormSection.insetGrouped(
          header: const Text('UNITS'),
          children: [
            CupertinoFormRow(
              prefix: const Text('Weights shown in'),
              child: CupertinoSlidingSegmentedControl<WeightUnit>(
                groupValue: _unit,
                children: {for (final u in WeightUnit.values) u: Text(u.name)},
                onValueChanged: (u) {
                  if (u != null) setState(() => _unit = u);
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: CupertinoButton.filled(
            key: const Key('submit-preferences'),
            onPressed: _submit,
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
