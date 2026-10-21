import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/weekdays.dart';
import '../../providers/schedule_providers.dart';

/// Planned meals for [date] that the user has not confirmed or dismissed.
/// Confirming logs the meal; nothing is logged automatically. Hidden when there
/// are none.
class ScheduledSuggestions extends ConsumerWidget {
  const ScheduledSuggestions({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(pendingScheduledProvider(date)).value ??
        const <PendingScheduledMeal>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('scheduled-suggestions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Planned',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        for (final p in pending)
          _SuggestionTile(
            key: Key('planned-${p.schedule.id}'),
            item: p,
            date: date,
          ),
      ],
    );
  }
}

class _SuggestionTile extends ConsumerWidget {
  const _SuggestionTile({super.key, required this.item, required this.date});

  final PendingScheduledMeal item;
  final String date;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .confirm(item.schedule.id, date: date);
    } catch (e) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialog) => CupertinoAlertDialog(
          title: const Text('Could not log meal'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _dismiss(BuildContext context, WidgetRef ref) {
    final repo = ref.read(scheduleRepositoryProvider);
    final id = item.schedule.id;
    final mask = item.schedule.weekdays;
    if (mask == null) {
      repo.dismiss(id, date: date);
      return;
    }
    // A repeating plan: skip just this day, or stop it for good.
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text('${item.meal.name} (${describeWeekdays(mask)})'),
        actions: [
          CupertinoActionSheetAction(
            key: const Key('planned-skip-day'),
            onPressed: () {
              Navigator.of(sheet).pop();
              repo.dismiss(id, date: date);
            },
            child: const Text('Skip this day'),
          ),
          CupertinoActionSheetAction(
            key: const Key('planned-stop-repeating'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheet).pop();
              repo.removeSchedule(id);
            },
            child: const Text('Stop repeating'),
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
    return CupertinoListTile(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      title: Text(item.meal.name),
      subtitle: Text(mask == null ? 'Planned' : describeWeekdays(mask)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            key: Key('planned-dismiss-${item.schedule.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(36, 36),
            onPressed: () => _dismiss(context, ref),
            child: const Text('Dismiss'),
          ),
          CupertinoButton.filled(
            key: Key('planned-confirm-${item.schedule.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(36, 32),
            onPressed: () => _confirm(context, ref),
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}
