import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auto_backup.dart';
import '../../core/backup_labels.dart';
import '../../data/repositories/backup_repository.dart';
import '../../providers/backup_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/error_feedback.dart';
import '../home/undo_banner.dart';

/// Settings section to export all data to a JSON file and restore from one.
/// Restoring replaces everything, so it asks first.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;

  void _setStatus(String? message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusIsError = error;
    });
  }

  final _exportKey = GlobalKey();

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    _setStatus(null);
    try {
      // Where the iPad share popover points.
      final box = _exportKey.currentContext?.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final json = await ref.read(backupRepositoryProvider).exportJson();
      final saved = await ref
          .read(backupFileIoProvider)
          .save(
            fileName: BackupRepository.fileNameFor(DateTime.now()),
            contents: json,
            origin: origin,
          );
      if (saved) {
        await ref.read(lastBackupProvider.notifier).markNow();
        _setStatus('Backup saved.');
      }
    } on Exception {
      _setStatus('Could not save the backup.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() =>
      _restoreFrom(() => ref.read(backupFileIoProvider).pick());

  /// Restores one of the automatic backups, picked from a list.
  Future<void> _restoreAutomatic() => _restoreFrom(() async {
    final name = await Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(builder: (_) => const AutoBackupListView()),
    );
    if (name == null) return null;
    return ref.read(autoBackupRunnerProvider).read(name);
  });

  /// Reads a backup's text from [source] (null when cancelled), shows what it
  /// holds and replaces everything once confirmed.
  Future<void> _restoreFrom(Future<String?> Function() source) async {
    if (_busy) return;
    setState(() => _busy = true);
    _setStatus(null);
    try {
      final contents = await source();
      if (contents == null || !mounted) return;
      final repo = ref.read(backupRepositoryProvider);
      // Decode first, so a bad file shows its error without asking anything.
      final data = repo.readBackup(contents);
      final summary = backupSummary(
        entries: data.logEntries.length,
        foods: data.foodItems.length,
        meals: data.meals.length,
        plans: data.scheduledMeals.length,
        exportedAt: data.exportedAt,
      );
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Replace all data?'),
          content: Text(
            'This file has $summary.\n\n'
            'Importing replaces your foods, meals, log, plans and settings '
            'with its contents. You can undo it right afterwards.',
            key: const Key('import-summary'),
          ),
          actions: [
            CupertinoDialogAction(
              key: const Key('import-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              key: const Key('import-confirm'),
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      // Kept in memory so the import can be undone.
      final previous = await repo.exportJson();
      await repo.restore(data);
      ref.invalidate(preferencesProvider);
      if (!mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      offerUndo(
        context,
        message: 'Backup imported',
        undo: () async {
          await repo.restore(repo.readBackup(previous));
          container.invalidate(preferencesProvider);
        },
      );
      // The settings form on screen is stale now; go back to Home.
      Navigator.of(context).pop();
    } on BackupException catch (e) {
      _setStatus(e.message, error: true);
    } on Exception {
      _setStatus('Could not read the backup file.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final now = DateTime.now();
    return CupertinoFormSection.insetGrouped(
      header: const Text('BACKUP'),
      footer: status == null
          ? Text(
              'Export saves everything to a JSON file. Automatic backups are '
              'written once a week, after the day\'s first entry; the newest '
              '$autoBackupsKept are kept on this phone.\n'
              '${lastBackupLabel(ref.watch(lastBackupProvider), now)}\n'
              '${lastAutoBackupLabel(ref.watch(userPreferencesProvider).readLastAutoBackup(), now)}',
              key: const Key('backup-last'),
            )
          : Text(
              status,
              key: const Key('backup-status'),
              style: TextStyle(
                color: _statusIsError ? CupertinoColors.systemRed : null,
              ),
            ),
      children: [
        KeyedSubtree(
          key: _exportKey,
          child: CupertinoListTile(
            key: const Key('backup-export'),
            title: const Text('Export data'),
            trailing: const CupertinoListTileChevron(),
            onTap: _busy ? null : _export,
          ),
        ),
        CupertinoListTile(
          key: const Key('backup-import'),
          title: const Text('Import data'),
          subtitle: const Text('Replaces everything'),
          trailing: const CupertinoListTileChevron(),
          onTap: _busy ? null : _import,
        ),
        CupertinoListTile(
          title: const Text('Automatic backups'),
          trailing: CupertinoSwitch(
            key: const Key('auto-backup-toggle'),
            value: ref.watch(autoBackupEnabledProvider),
            onChanged: (on) =>
                ref.read(autoBackupEnabledProvider.notifier).set(on),
          ),
        ),
        CupertinoListTile(
          key: const Key('auto-backup-restore'),
          title: const Text('Restore automatic backup'),
          subtitle: const Text('Replaces everything'),
          trailing: const CupertinoListTileChevron(),
          onTap: _busy ? null : _restoreAutomatic,
        ),
      ],
    );
  }
}

/// The automatic backups on this phone, newest first. Pops with the chosen
/// file name.
class AutoBackupListView extends ConsumerWidget {
  const AutoBackupListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Automatic backups'),
      ),
      child: SafeArea(
        child: FutureBuilder<List<String>>(
          future: ref.read(autoBackupRunnerProvider).list(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return LoadErrorText(
                failed: 'Could not list the automatic backups',
                error: snapshot.error!,
                stack: snapshot.stackTrace,
              );
            }
            final names = snapshot.data;
            if (names == null) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (names.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No automatic backups yet. One is written after the '
                    'first entry of the day, once a week.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final format = DateFormat.yMMMMd();
            return ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  children: [
                    for (final name in names)
                      CupertinoListTile(
                        key: Key('auto-backup-$name'),
                        title: Text(format.format(autoBackupDate(name)!)),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => Navigator.of(context).pop(name),
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
