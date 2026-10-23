import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../core/metrics.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/today_providers.dart';
import 'edit_entry_sheets.dart';
import 'entry_sheets.dart';
import 'undo_banner.dart';

/// The day's entries as a sliver. Swipe left to delete (with a short Undo
/// banner); tap a food entry to edit its servings, a meal entry to see its
/// breakdown or a one-off entry to edit it; long-press any entry to move it to
/// another day.
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
    // Read everything the banner needs now: this list is gone once the last
    // entry of the day is deleted, but the banner and its Undo must outlive it.
    final repo = ref.read(logRepositoryProvider);
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context, rootNavigator: true);
    setState(() => _dismissed.add(id));
    try {
      final deleted = await repo.deleteEntryForUndo(id);
      if (deleted == null) return;
      showUndoBanner(
        overlay,
        message: 'Entry deleted',
        onUndo: () async {
          try {
            await repo.restoreEntry(deleted);
          } catch (e) {
            if (navigator.mounted) {
              showCupertinoDialog<void>(
                context: navigator.context,
                builder: (dialogContext) => CupertinoAlertDialog(
                  content: Text('Could not undo: $e'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
          if (mounted) setState(() => _dismissed.remove(id));
        },
      );
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

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.onDelete});

  final FoodLogEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const _DeleteBackground(),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onLongPress: () => _showActions(context, ref),
        child: CupertinoListTile(
          backgroundColor: CupertinoColors.systemBackground.resolveFrom(
            context,
          ),
          title: Text(entry.name),
          subtitle: Text(_describe(entry)),
          trailing: Text('${Metric.calories.format(entry.calories)} kcal'),
          onTap: () => _open(context),
        ),
      ),
    );
  }

  /// Copies the entry onto today, with an Undo banner. Reads everything it
  /// needs up front, because the action sheet that started it is already gone.
  Future<void> _logAgain(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(logRepositoryProvider);
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final newId = await repo.duplicateEntry(
        entry.id,
        ref.read(todayProvider),
      );
      showUndoBanner(
        overlay,
        message: 'Logged again today',
        onUndo: () => repo.deleteEntry(newId),
      );
    } catch (e) {
      if (navigator.mounted) {
        showCupertinoDialog<void>(
          context: navigator.context,
          builder: (dialogContext) => CupertinoAlertDialog(
            content: Text('Could not log again: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Long-press menu, shared by every entry type.
  void _showActions(BuildContext context, WidgetRef ref) {
    // Logging an entry again onto the day it is already on is pointless.
    final canLogAgain = entry.logDate != ref.read(todayProvider);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(entry.name),
        actions: [
          if (canLogAgain)
            CupertinoActionSheetAction(
              key: const Key('log-again-today'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _logAgain(context, ref);
              },
              child: const Text('Log again today'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              showMoveEntryPicker(context, entry: entry);
            },
            child: const Text('Move to another day'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
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
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => EditAdhocSheet(entry: entry),
        );
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

/// Shown for a day with no entries. Offers to copy the day before when that
/// day has entries.
class EmptyLogState extends ConsumerStatefulWidget {
  const EmptyLogState({super.key, required this.date});

  final String date;

  @override
  ConsumerState<EmptyLogState> createState() => _EmptyLogStateState();
}

class _EmptyLogStateState extends ConsumerState<EmptyLogState> {
  /// True while a copy is running, so a second tap cannot copy the day twice.
  bool _copying = false;

  Future<void> _copy(String previous) async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      await ref
          .read(logRepositoryProvider)
          .copyDay(fromDate: previous, toDate: widget.date);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previous = addDays(widget.date, -1);
    final hasPrevious =
        (ref.watch(dayEntriesProvider(previous)).value ?? const []).isNotEmpty;
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
            if (hasPrevious) ...[
              const SizedBox(height: 16),
              CupertinoButton.filled(
                key: const Key('copy-previous-day'),
                onPressed: _copying ? null : () => _copy(previous),
                child: Text(
                  previous == addDays(ref.watch(todayProvider), -1)
                      ? 'Copy yesterday'
                      : 'Copy previous day',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
