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
    this.extraSections = const [],
  });

  final UserSettings initial;
  final String submitLabel;

  /// Called with the validated settings. `onboardingComplete` is copied from
  /// [initial]; the caller decides whether to change it.
  final ValueChanged<UserSettings> onSubmit;

  /// Extra sections shown between the units and the submit button (Settings
  /// puts Backup here).
  final List<Widget> extraSections;

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

  CupertinoFormSection _trackSection({
    required String header,
    required String footer,
    required Iterable<Metric> metrics,
  }) {
    return CupertinoFormSection.insetGrouped(
      header: Text(header),
      footer: Text(footer),
      children: [
        for (final m in metrics)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // At large text sizes a goal's label goes above its field, since beside
    // it the label leaves the field almost no width.
    final stackGoalLabels = MediaQuery.textScalerOf(context).scale(10) > 15;
    return ListView(
      // Dragging the list hides the keyboard, so the goal fields never trap it.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        CupertinoFormSection.insetGrouped(
          header: const Text('PRIMARY METRIC'),
          footer: const Text('Shown large on the Today screen.'),
          children: [
            // Fiber, sugar and sodium can be tracked but not made primary.
            for (final m in Metric.values.where((m) => !m.isOptional))
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
        _trackSection(
          header: 'TRACK',
          footer: 'The primary metric is always tracked.',
          metrics: Metric.values.where((m) => !m.isOptional),
        ),
        CupertinoFormSection.insetGrouped(
          header: const Text('DAILY GOALS'),
          footer: const Text('Leave blank for no goal.'),
          children: [
            for (final m in Metric.values.where(_tracked.contains))
              CupertinoFormRow(
                prefix: stackGoalLabels ? null : Text(m.label),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (stackGoalLabels)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(m.label),
                      ),
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
        // After the goals, so the common layout stays short. A goal row for a
        // newly tracked nutrient appears at the end of the goals above.
        _trackSection(
          header: 'ALSO TRACK',
          footer:
              'Optional on each food. Totals count a missing value as 0 and '
              'say how many entries recorded it.',
          metrics: Metric.optional,
        ),
        CupertinoFormSection.insetGrouped(
          // The label is the header, not a row prefix: at large text sizes a
          // prefix leaves the control no width.
          header: const Text('SHOW WEIGHTS IN'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<WeightUnit>(
                  groupValue: _unit,
                  children: {
                    for (final u in WeightUnit.values) u: Text(u.name),
                  },
                  onValueChanged: (u) {
                    if (u != null) setState(() => _unit = u);
                  },
                ),
              ),
            ),
          ],
        ),
        ...widget.extraSections,
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
