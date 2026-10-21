import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../core/weekdays.dart';
import '../../data/database/app_database.dart';
import '../../providers/schedule_providers.dart';
import '../home/date_header.dart';

enum _Repeat { once, weekdays }

/// Plans [meal] for a day, or for repeating weekdays from that day on. The plan
/// only shows up as a suggestion on Home; nothing is logged until confirmed.
/// Pops itself after saving.
class ScheduleMealView extends ConsumerStatefulWidget {
  const ScheduleMealView({
    super.key,
    required this.meal,
    required this.initialDate,
  });

  final Meal meal;

  /// 'yyyy-MM-dd' the date picker starts on.
  final String initialDate;

  @override
  ConsumerState<ScheduleMealView> createState() => _ScheduleMealViewState();
}

class _ScheduleMealViewState extends ConsumerState<ScheduleMealView> {
  late String _date = widget.initialDate;
  _Repeat _repeat = _Repeat.once;
  // DateTime.weekday values; Mon-Fri to start with.
  final Set<int> _days = {1, 2, 3, 4, 5};
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    if (_repeat == _Repeat.weekdays && _days.isEmpty) {
      setState(() => _error = 'Pick at least one day');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(scheduleRepositoryProvider);
      if (_repeat == _Repeat.once) {
        await repo.scheduleOnce(mealId: widget.meal.id, date: _date);
      } else {
        await repo.scheduleWeekdays(
          mealId: widget.meal.id,
          startDate: _date,
          weekdays: _days,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not schedule meal: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repeating = _repeat == _Repeat.weekdays;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: const Text('Schedule'),
        trailing: CupertinoButton(
          key: const Key('schedule-save'),
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                widget.meal.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<_Repeat>(
                key: const Key('schedule-repeat'),
                groupValue: _repeat,
                children: const {
                  _Repeat.once: Text('One day'),
                  _Repeat.weekdays: Text('Repeat weekly'),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => _repeat = v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                repeating ? 'Starting' : 'On',
                style: TextStyle(color: secondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                dayLabel(_date, today: todayKey()),
                key: const Key('schedule-date'),
                style: const TextStyle(fontSize: 17),
              ),
            ),
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: dateFromKey(widget.initialDate),
                onDateTimeChanged: (d) => setState(() => _date = dateKey(d)),
              ),
            ),
            if (repeating) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Repeats on', style: TextStyle(color: secondary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 4,
                  children: [
                    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                      _DayChip(
                        key: Key('weekday-$d'),
                        label: weekdayLabels[d - 1],
                        selected: _days.contains(d),
                        onTap: () => setState(() {
                          _days.contains(d) ? _days.remove(d) : _days.add(d);
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(44, 36),
      color: selected
          ? CupertinoTheme.of(context).primaryColor
          : CupertinoColors.tertiarySystemFill.resolveFrom(context),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: selected
              ? CupertinoColors.white
              : CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}
