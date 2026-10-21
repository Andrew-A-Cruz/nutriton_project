import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import 'entry_sheets.dart';

/// The day's entries as a sliver. Swipe left to delete; tap a food entry to
/// edit its servings or a meal entry to see its breakdown.
class DayLogList extends ConsumerStatefulWidget {
  const DayLogList({super.key, required this.entries});

  final List<FoodLogEntry> entries;

  @override
  ConsumerState<DayLogList> createState() => _DayLogListState();
}

class _DayLogListState extends ConsumerState<DayLogList> {
  /// Entries swiped away whose delete has not reached the stream yet. They are
  /// hidden at once, because a dismissed Dismissible must leave the tree on the
  /// frame it is dismissed.
  final _dismissed = <String>{};

  Future<void> _delete(String id) async {
    setState(() => _dismissed.add(id));
    try {
      await ref.read(logRepositoryProvider).deleteEntry(id);
    } catch (_) {
      if (mounted) setState(() => _dismissed.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final e in widget.entries)
        if (!_dismissed.contains(e.id)) e,
    ];
    return SliverList.builder(
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final entry = visible[i];
        return _EntryTile(entry: entry, onDelete: () => _delete(entry.id));
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});

  final FoodLogEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const _DeleteBackground(),
      onDismissed: (_) => onDelete(),
      child: CupertinoListTile(
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        title: Text(entry.name),
        subtitle: Text(_describe(entry)),
        trailing: Text('${Metric.calories.format(entry.calories)} kcal'),
        onTap: () => _open(context),
      ),
    );
  }

  String _describe(FoodLogEntry e) => switch (e.entryType) {
    'food' =>
      '${plainNumber(e.servings ?? 0)} serving${e.servings == 1 ? '' : 's'}',
    'meal' => 'Meal',
    _ => 'Custom food',
  };

  void _open(BuildContext context) {
    switch (entry.entryType) {
      case 'food':
        showCupertinoDialog<void>(
          context: context,
          builder: (_) => EditServingsDialog(entry: entry),
        );
      case 'meal':
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => MealBreakdownSheet(entry: entry),
        );
      default:
        // Ad hoc entries have nothing to edit or break down.
        break;
    }
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemRed,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Text(
        'Delete',
        style: TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shown when nothing is logged for the selected day.
class EmptyLogState extends StatelessWidget {
  const EmptyLogState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.square_list,
              size: 48,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nothing logged yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to log a food or meal.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
