import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/fasting.dart';
import '../../data/database/app_database.dart';
import '../../providers/fasting_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/error_feedback.dart';

/// Settings section for the fasting timer: the switch that shows it on
/// Today, and the history. The switch saves at once, like the reminders.
class FastingSection extends ConsumerWidget {
  const FastingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      preferencesProvider.select((s) => s.fastingEnabled),
    );
    final count = ref.watch(finishedFastsProvider).value?.length;
    return CupertinoFormSection.insetGrouped(
      header: const Text('FASTING'),
      footer: const Text(
        'A timer on Today to start and end a fast. Turning it off hides the '
        'timer and keeps the history.',
      ),
      children: [
        CupertinoListTile(
          title: const Text('Fasting Timer'),
          trailing: CupertinoSwitch(
            key: const Key('fasting-enabled'),
            value: enabled,
            onChanged: (on) {
              final settings = ref.read(preferencesProvider);
              ref
                  .read(preferencesProvider.notifier)
                  .save(settings.copyWith(fastingEnabled: on));
            },
          ),
        ),
        if (enabled || (count ?? 0) > 0)
          CupertinoListTile(
            key: const Key('fasting-history'),
            title: const Text('Fasting History'),
            additionalInfo: count == null ? null : Text('$count'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => const FastingHistoryView(),
              ),
            ),
          ),
      ],
    );
  }
}

/// 'Wed, Nov 11, 8:00 PM – Thu, Nov 12, 12:00 PM', or with one day name when
/// the fast ended the day it began.
String describeFastSpan(DateTime startedAt, DateTime endedAt) {
  final day = DateFormat('EEE, MMM d');
  // An explicit pattern: jm() puts a narrow no-break space before AM and PM.
  final time = DateFormat('h:mm a');
  final sameDay =
      startedAt.year == endedAt.year &&
      startedAt.month == endedAt.month &&
      startedAt.day == endedAt.day;
  final start = '${day.format(startedAt)}, ${time.format(startedAt)}';
  final end = sameDay
      ? time.format(endedAt)
      : '${day.format(endedAt)}, ${time.format(endedAt)}';
  return '$start – $end';
}

/// Every finished fast, newest first, each with its length and a button to
/// remove it.
class FastingHistoryView extends ConsumerWidget {
  const FastingHistoryView({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, Fast fast) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Remove this fast?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            key: const Key('fast-remove-confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(fastingRepositoryProvider).delete(fast.id);
    } catch (e, stack) {
      if (context.mounted) {
        await showErrorDialog(
          context,
          reportError(ref, e, stack, 'Could not remove the fast'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasts = ref.watch(finishedFastsProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Fasting History'),
      ),
      child: SafeArea(
        child: fasts.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => LoadErrorText(
            failed: 'Could not load the fasts',
            error: error,
            stack: stack,
          ),
          data: (all) {
            if (all.isEmpty) {
              return Center(
                key: const Key('fasts-empty'),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No fasts yet. Start one from the Today screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView(
              children: [
                CupertinoFormSection.insetGrouped(
                  children: [
                    for (final f in all)
                      CupertinoListTile(
                        key: Key('fast-${f.id}'),
                        title: Text(
                          formatFastLength(fastLength(f.startedAt, f.endedAt!)),
                        ),
                        subtitle: Text(
                          describeFastSpan(f.startedAt, f.endedAt!),
                        ),
                        trailing: CupertinoButton(
                          key: Key('fast-remove-${f.id}'),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(44),
                          onPressed: () => _remove(context, ref, f),
                          child: Icon(
                            CupertinoIcons.trash,
                            semanticLabel: 'Remove this fast',
                            color: CupertinoColors.systemRed.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
