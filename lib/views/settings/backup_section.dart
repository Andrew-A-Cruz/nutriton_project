import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup_labels.dart';
import '../../data/repositories/backup_repository.dart';
import '../../providers/backup_providers.dart';
import '../../providers/preferences_providers.dart';

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

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    _setStatus(null);
    try {
      final contents = await ref.read(backupFileIoProvider).pick();
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
            'with its contents. This cannot be undone.',
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
      await repo.restore(data);
      ref.invalidate(preferencesProvider);
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Backup restored'),
          content: const Text('Your data has been replaced.'),
          actions: [
            CupertinoDialogAction(
              key: const Key('import-done'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      // The settings form on screen is stale now; go back to Home.
      if (mounted) Navigator.of(context).pop();
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
    return CupertinoFormSection.insetGrouped(
      header: const Text('BACKUP'),
      footer: status == null
          ? Text(
              'Export saves everything to a JSON file.\n'
              '${lastBackupLabel(ref.watch(lastBackupProvider), DateTime.now())}',
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
      ],
    );
  }
}
