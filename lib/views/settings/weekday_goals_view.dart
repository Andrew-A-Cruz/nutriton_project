import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/macro_split.dart';
import '../../core/metrics.dart';
import '../../core/validation.dart';
import '../../core/weekdays.dart';
import '../../data/preferences/user_preferences.dart';
import '../../providers/preferences_providers.dart';

const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The metrics a weekday can set: the tracked ones, except protein, carbs and
/// fat in percent mode, which follow the day's calorie goal.
List<Metric> _editable(UserSettings s) => [
  for (final m in Metric.values)
    if (s.trackedMetrics.contains(m) &&
        !(s.macroGoalPercents != null && macroMetrics.contains(m)))
      m,
];

/// Settings row that opens [WeekdayGoalsView].
class WeekdayGoalsSection extends ConsumerWidget {
  const WeekdayGoalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(preferencesProvider);
    final days = settings.weekdayGoals.length;
    return CupertinoFormSection.insetGrouped(
      header: const Text('GOALS BY WEEKDAY'),
      footer: const Text(
        'Different goals on some days, such as training days. Other days use '
        'the daily goals above.',
      ),
      children: [
        CupertinoListTile(
          key: const Key('weekday-goals'),
          title: const Text('Goals by weekday'),
          additionalInfo: Text(
            days == 0 ? 'Off' : '$days day${days == 1 ? '' : 's'}',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => const WeekdayGoalsView()),
          ),
        ),
      ],
    );
  }
}

/// The seven weekdays, each with its own goals or "Usual goals".
class WeekdayGoalsView extends ConsumerWidget {
  const WeekdayGoalsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(preferencesProvider);
    String describe(int day) {
      final own = settings.weekdayGoals[day];
      if (own == null || own.isEmpty) return 'Usual goals';
      return [
        for (final m in Metric.values)
          if (own[m] case final g?) m.formatWithUnit(g),
      ].join(', ');
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Goals by weekday'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              children: [
                for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                  CupertinoListTile(
                    key: Key('weekday-goals-${weekdayKeys[d - 1]}'),
                    title: Text(_dayNames[d - 1]),
                    subtitle: Text(describe(d)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => _WeekdayEditor(weekday: d),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One weekday's goals. A blank field uses the usual goal.
class _WeekdayEditor extends ConsumerStatefulWidget {
  const _WeekdayEditor({required this.weekday});

  final int weekday;

  @override
  ConsumerState<_WeekdayEditor> createState() => _WeekdayEditorState();
}

class _WeekdayEditorState extends ConsumerState<_WeekdayEditor> {
  late final UserSettings _initial = ref.read(preferencesProvider);
  late final Map<Metric, TextEditingController> _fields = {
    for (final m in _editable(_initial))
      m: TextEditingController(
        text: switch (_initial.weekdayGoals[widget.weekday]?[m]) {
          null => '',
          final g => plainNumber(g),
        },
      ),
  };
  final Map<Metric, String> _errors = {};

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final goals = <Metric, double>{};
    final errors = <Metric, String>{};
    _fields.forEach((m, c) {
      final text = c.text.trim();
      if (text.isEmpty) return;
      final v = parseNumber(text);
      if (v == null || v <= 0) {
        errors[m] = 'Enter a number greater than 0, or leave it blank';
      } else {
        goals[m] = v;
      }
    });
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty) return;
    final current = ref.read(preferencesProvider);
    await ref
        .read(preferencesProvider.notifier)
        .save(
          current.copyWith(
            weekdayGoals: {...current.weekdayGoals, widget.weekday: goals},
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  void _clear() {
    for (final c in _fields.values) {
      c.clear();
    }
    setState(_errors.clear);
  }

  @override
  Widget build(BuildContext context) {
    final percent = _initial.macroGoalPercents != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_dayNames[widget.weekday - 1]),
        trailing: CupertinoButton(
          key: const Key('weekday-goals-save'),
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            CupertinoFormSection.insetGrouped(
              header: Text(
                '${weekdayLabels[widget.weekday - 1].toUpperCase()} GOALS',
              ),
              footer: Text(
                'Leave a goal blank to use the usual one.'
                '${percent ? ' Protein, carbs and fat stay a share of the '
                          'calorie goal.' : ''}',
              ),
              children: [
                for (final MapEntry(key: m, value: c) in _fields.entries)
                  CupertinoFormRow(
                    prefix: Text(m.label),
                    error: _errors[m] == null ? null : Text(_errors[m]!),
                    child: CupertinoTextField(
                      key: Key('weekday-goal-${m.name}'),
                      controller: c,
                      placeholder: switch (_initial.goalFor(m)) {
                        null => 'No goal',
                        final g => plainNumber(g),
                      },
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(m.unit),
                      ),
                    ),
                  ),
              ],
            ),
            CupertinoButton(
              key: const Key('weekday-goals-clear'),
              onPressed: _clear,
              child: const Text('Use the usual goals'),
            ),
          ],
        ),
      ),
    );
  }
}
