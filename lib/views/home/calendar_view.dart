import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_math.dart';
import '../../core/date_key.dart';
import '../../core/summary_math.dart';
import '../../providers/log_providers.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/summary_providers.dart';
import '../../providers/today_providers.dart';

/// Opens the calendar on the month of [date]. Picking a day shows it on
/// Today.
Future<void> showLogCalendar(BuildContext context, {required String date}) =>
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LogCalendarView(initialDate: date),
      ),
    );

/// A month of days with a dot on each logged one, colored by the primary
/// metric against its goal. Tapping a day jumps Today there, so it is also a
/// "go to date" picker.
class LogCalendarView extends ConsumerStatefulWidget {
  const LogCalendarView({super.key, required this.initialDate});

  /// The day Today is showing; it is circled.
  final String initialDate;

  @override
  ConsumerState<LogCalendarView> createState() => _LogCalendarViewState();
}

class _LogCalendarViewState extends ConsumerState<LogCalendarView> {
  late Month _month = monthOf(widget.initialDate);

  void _pick(String key) {
    ref.read(selectedDateProvider.notifier).select(key);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final settings = ref.watch(preferencesProvider);
    final mindful = ref.watch(mindfulModeProvider);
    final metric = settings.primaryMetric;
    double? goalOn(String day) =>
        mindful ? null : settings.goalFor(metric, date: day);
    final withGoal =
        !mindful &&
        settings.averageGoal(
              metric,
              monthSpan(_month).$1,
              monthSpan(_month).$2,
            ) !=
            null;
    final totals = ref.watch(monthTotalsProvider(_month)).value ?? const {};
    final title = DateFormat.yMMMM().format(
      DateTime(_month.year, _month.month),
    );
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const Key('calendar-close'),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        middle: const Text('Calendar'),
        trailing: CupertinoButton(
          key: const Key('calendar-today'),
          padding: EdgeInsets.zero,
          onPressed: () => _pick(today),
          child: const Text('Today'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Row(
              children: [
                CupertinoButton(
                  key: const Key('calendar-previous'),
                  onPressed: () =>
                      setState(() => _month = addMonths(_month, -1)),
                  child: const Icon(
                    CupertinoIcons.chevron_left,
                    semanticLabel: 'Previous month',
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('calendar-month'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  key: const Key('calendar-next'),
                  onPressed: () =>
                      setState(() => _month = addMonths(_month, 1)),
                  child: const Icon(
                    CupertinoIcons.chevron_right,
                    semanticLabel: 'Next month',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final week in monthGrid(_month))
              Row(
                children: [
                  for (final key in week)
                    Expanded(
                      child: key == null
                          ? const SizedBox(height: 48)
                          : _DayCell(
                              dateKey: key,
                              mark: dayMark(totals[key], metric, goalOn(key)),
                              isToday: key == today,
                              isSelected: key == widget.initialDate,
                              onTap: () => _pick(key),
                            ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            _Legend(withGoal: withGoal),
          ],
        ),
      ),
    );
  }
}

/// Dot colors, the same as the Summary bars.
Color? _markColor(BuildContext context, DayMark mark) => switch (mark) {
  DayMark.none => null,
  DayMark.logged => CupertinoColors.systemGrey.resolveFrom(context),
  DayMark.under => CupertinoColors.activeBlue.resolveFrom(context),
  DayMark.onTarget => CupertinoColors.systemGreen.resolveFrom(context),
  DayMark.over => CupertinoColors.systemRed.resolveFrom(context),
};

String _markText(DayMark mark) => switch (mark) {
  DayMark.none => 'nothing logged',
  DayMark.logged => 'logged',
  DayMark.under => 'logged, under goal',
  DayMark.onTarget => 'logged, on target',
  DayMark.over => 'logged, over goal',
};

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dateKey,
    required this.mark,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final String dateKey;
  final DayMark mark;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = dateFromKey(dateKey);
    final accent = CupertinoTheme.of(context).primaryColor;
    final dot = _markColor(context, mark);
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${DateFormat.MMMMd().format(date)}${isToday ? ', today' : ''}, '
          '${_markText(mark)}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('calendar-day-$dateKey'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: isSelected
                    ? BoxDecoration(color: accent, shape: BoxShape.circle)
                    : null,
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? CupertinoColors.white
                        : isToday
                        ? accent
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: dot ?? const Color(0x00000000),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.withGoal});

  final bool withGoal;

  @override
  Widget build(BuildContext context) {
    final items = withGoal
        ? [
            (DayMark.under, 'Under goal'),
            (
              DayMark.onTarget,
              'Within ${(goalTolerance * 100).round()}% of the goal',
            ),
            (DayMark.over, 'Over goal'),
          ]
        : [(DayMark.logged, 'Logged')];
    return ExcludeSemantics(
      child: Wrap(
        key: const Key('calendar-legend'),
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final (mark, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _markColor(context, mark),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 8),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
