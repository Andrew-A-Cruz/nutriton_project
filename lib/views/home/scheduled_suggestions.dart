import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/weekdays.dart';
import '../../providers/schedule_providers.dart';

/// One planned meal or food inside its meal section on Home, dimmed so it
/// reads as a suggestion and not as something eaten. Tap to log it (nothing is
/// logged automatically); swipe left to skip it for [date]; long-press for
/// "Stop repeating" on a repeating plan. It counts toward no totals until it
/// has been logged.
class PlannedTile extends ConsumerWidget {
  const PlannedTile({
    super.key,
    required this.item,
    required this.date,
    required this.onSkipped,
  });

  final PendingScheduledMeal item;
  final String date;

  /// Called when the tile is swiped away, so the list can hide it at once. The
  /// outcome is written by the tile.
  final VoidCallback onSkipped;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .confirm(item.schedule.id, date: date);
    } catch (e) {
      if (!context.mounted) return;
      await _showError(context, 'Could not log ${item.name}', '$e');
    }
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    onSkipped();
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .dismiss(item.schedule.id, date: date);
    } catch (e) {
      if (!context.mounted) return;
      await _showError(context, 'Could not skip ${item.name}', '$e');
    }
  }

  Future<void> _showError(BuildContext context, String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final repo = ref.read(scheduleRepositoryProvider);
    final id = item.schedule.id;
    final mask = item.schedule.weekdays;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(
          mask == null ? item.name : '${item.name} (${describeWeekdays(mask)})',
        ),
        actions: [
          CupertinoActionSheetAction(
            key: const Key('planned-skip-day'),
            onPressed: () {
              Navigator.of(sheet).pop();
              _skip(context, ref);
            },
            child: Text(mask == null ? 'Skip' : 'Skip this day'),
          ),
          CupertinoActionSheetAction(
            key: const Key('planned-stop-repeating'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheet).pop();
              repo.removeSchedule(id);
            },
            child: Text(mask == null ? 'Remove plan' : 'Stop repeating'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mask = item.schedule.weekdays;
    final servings = item.schedule.servings;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Dismissible(
      key: Key('planned-${item.schedule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CupertinoColors.systemGrey,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Text(
          'Skip',
          style: TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onDismissed: (_) => _skip(context, ref),
      child: GestureDetector(
        onLongPress: () => _showActions(context, ref),
        child: Opacity(
          opacity: 0.55,
          child: CupertinoListTile(
            key: Key('planned-tile-${item.schedule.id}'),
            backgroundColor: CupertinoColors.systemBackground.resolveFrom(
              context,
            ),
            title: Text(item.name),
            subtitle: Text(
              [
                mask == null ? 'Planned' : describeWeekdays(mask),
                if (servings != 1)
                  '${plainNumber(roundTo(servings, 2))} servings',
              ].join(' · '),
            ),
            trailing: Text(
              'Tap to log',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
            onTap: () => _confirm(context, ref),
          ),
        ),
      ),
    );
  }
}
