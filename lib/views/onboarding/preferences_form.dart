import 'package:flutter/cupertino.dart';

import '../../core/body_weight.dart';
import '../../core/macro_split.dart';
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
  late BodyWeightUnit _bodyUnit = widget.initial.bodyWeightUnit;
  late final Map<Metric, TextEditingController> _goals = {
    for (final m in Metric.values)
      m: TextEditingController(
        text: widget.initial.goalFor(m) == null
            ? ''
            : plainNumber(widget.initial.goalFor(m)!),
      ),
  };
  final Map<Metric, String> _errors = {};

  /// Protein, carbs and fat goals as % of the calorie goal instead of grams.
  late bool _percentMode = widget.initial.macroGoalPercents != null;
  late final Map<Metric, TextEditingController> _percents = {
    for (final m in macroMetrics)
      m: TextEditingController(text: '${percentOf(_startingPercents(), m)}'),
  };

  /// The saved percentages, else today's gram goals as percentages, else a
  /// common 30 / 40 / 30.
  MacroSplit _startingPercents() {
    final initial = widget.initial;
    if (initial.macroGoalPercents case final p?) return p;
    final grams = [for (final m in macroMetrics) initial.goalFor(m)];
    if (!grams.contains(null)) {
      final split = macroSplit(
        Macros(
          calories: 0,
          protein: grams[0]!,
          carbs: grams[1]!,
          fat: grams[2]!,
        ),
      );
      if (split != null) return split;
    }
    return (protein: 30, carbs: 40, fat: 30);
  }

  /// Percentages apply only while calories are tracked.
  bool get _usePercents => _percentMode && _tracked.contains(Metric.calories);

  @override
  void dispose() {
    for (final controller in [..._goals.values, ..._percents.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final errors = <Metric, String>{};
    final goals = <Metric, double>{};
    MacroSplit? percents;
    if (_usePercents) {
      final parts = [
        for (final m in macroMetrics) parseNumber(_percents[m]!.text.trim()),
      ];
      if (parts.any((p) => p == null || p < 0 || p != p.roundToDouble())) {
        errors[Metric.fat] = 'Enter whole percentages';
      } else {
        final ints = [for (final p in parts) p!.round()];
        percents = validMacroSplit(ints[0], ints[1], ints[2]);
        if (percents == null) {
          errors[Metric.fat] =
              'The percentages add up to ${ints.fold<int>(0, (a, b) => a + b)}%, '
              'not 100%';
        }
      }
    }
    for (final m in Metric.values) {
      // Derived from the calorie goal instead.
      if (_usePercents && macroMetrics.contains(m)) continue;
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
    if (_usePercents && goals[Metric.calories] == null) {
      errors[Metric.calories] = 'Enter a calorie goal to set macros as %';
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
        bodyWeightUnit: _bodyUnit,
        macroGoalPercents: percents,
      ),
    );
  }

  /// Grams the typed percentage for [m] works out to, e.g. '= 150 g', or null.
  String? _gramsHint(Metric m) {
    final calories = parseNumber(_goals[Metric.calories]!.text.trim());
    final percent = parseNumber(_percents[m]!.text.trim());
    if (calories == null || calories <= 0 || percent == null || percent < 0) {
      return null;
    }
    final grams = calories * percent / 100 / kcalPerGram(m);
    return '= ${m.formatWithUnit(grams)}';
  }

  Widget _goalField(Metric m) {
    if (_usePercents && macroMetrics.contains(m)) {
      final hint = _gramsHint(m);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CupertinoTextField(
            key: Key('goal-percent-${m.name}'),
            controller: _percents[m],
            textAlign: TextAlign.end,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            suffix: const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text('%'),
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint,
                key: Key('goal-grams-${m.name}'),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
        ],
      );
    }
    return CupertinoTextField(
      key: Key('goal-${m.name}'),
      controller: _goals[m],
      placeholder: 'No goal',
      textAlign: TextAlign.end,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Percent hints follow the calorie goal as it is typed.
      onChanged: m == Metric.calories && _usePercents
          ? (_) => setState(() {})
          : null,
      suffix: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(m.unit),
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
          footer: Text(
            _usePercents
                ? 'Protein, carbs and fat are a share of the calorie goal and '
                      'must add up to 100%. Leave other goals blank for none.'
                : 'Leave blank for no goal.',
          ),
          children: [
            if (_tracked.contains(Metric.calories))
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<bool>(
                    key: const Key('macro-goal-mode'),
                    groupValue: _percentMode,
                    children: const {
                      false: Text('Macros in grams'),
                      true: Text('% of calories'),
                    },
                    onValueChanged: (v) {
                      if (v != null) setState(() => _percentMode = v);
                    },
                  ),
                ),
              ),
            // In % mode all three macros need a share, tracked or not.
            for (final m in Metric.values.where(
              (m) =>
                  _tracked.contains(m) ||
                  (_usePercents && macroMetrics.contains(m)),
            ))
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
                    _goalField(m),
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
        CupertinoFormSection.insetGrouped(
          header: const Text('BODY WEIGHT IN'),
          footer: const Text('Kept apart from the food unit above.'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<BodyWeightUnit>(
                  key: const Key('body-weight-unit'),
                  groupValue: _bodyUnit,
                  children: {
                    for (final u in BodyWeightUnit.values) u: Text(u.name),
                  },
                  onValueChanged: (u) {
                    if (u != null) setState(() => _bodyUnit = u);
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
