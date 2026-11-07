import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/auto_backup.dart';
import '../data/backup/auto_backup_store.dart';
import '../data/backup/backup_file_io.dart';
import '../data/repositories/backup_repository.dart';
import 'infrastructure_providers.dart';
import 'log_providers.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

export '../data/backup/backup_file_io.dart' show BackupFileIo;
export '../data/repositories/backup_repository.dart' show BackupException;

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(
    ref.watch(databaseProvider),
    ref.watch(userPreferencesProvider),
  ),
);

/// Tests override this with a fake that never touches the file system.
final backupFileIoProvider = Provider<BackupFileIo>(
  (ref) => const FilePickerBackupFileIo(),
);

/// When the last export succeeded, or null if never. Lives outside
/// `UserSettings`, so importing a backup does not touch it.
class LastBackupNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.watch(userPreferencesProvider).readLastBackup();

  Future<void> markNow() async {
    final now = DateTime.now();
    state = now;
    await ref.read(userPreferencesProvider).writeLastBackup(now);
  }
}

final lastBackupProvider = NotifierProvider<LastBackupNotifier, DateTime?>(
  LastBackupNotifier.new,
);

/// Where automatic backups are written. A no-op until `main` overrides it, so
/// tests and unsupported platforms never touch the file system.
final autoBackupStoreProvider = Provider<AutoBackupStore>(
  (ref) => const NoopAutoBackupStore(),
);

final autoBackupRunnerProvider = Provider<AutoBackupRunner>(
  (ref) => AutoBackupRunner(
    repository: ref.watch(backupRepositoryProvider),
    store: ref.watch(autoBackupStoreProvider),
    preferences: ref.watch(userPreferencesProvider),
  ),
);

/// Whether automatic backups are on. Device-local, so an import does not
/// change it.
class AutoBackupEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(userPreferencesProvider).readAutoBackupEnabled();

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(userPreferencesProvider).writeAutoBackupEnabled(enabled);
  }
}

final autoBackupEnabledProvider =
    NotifierProvider<AutoBackupEnabledNotifier, bool>(
      AutoBackupEnabledNotifier.new,
    );

/// Writes the week's automatic backup once today's log has an entry. Watched
/// from the root, so it runs at launch, at the day rollover and when today's
/// first entry is logged. A failure goes to the error log and is retried on
/// the next trigger.
final autoBackupPlanProvider = Provider<void>((ref) {
  if (!ref.watch(autoBackupEnabledProvider)) return;
  final today = ref.watch(todayProvider);
  final loggedToday = ref.watch(dayEntriesProvider(today)).value?.isNotEmpty;
  if (loggedToday != true) return;
  final errorLog = ref.read(errorLogProvider);
  unawaited(
    ref
        .read(autoBackupRunnerProvider)
        .runIfDue(ref.read(clockProvider)())
        .then<void>((_) {})
        .catchError(
          (Object e, StackTrace stack) =>
              errorLog.record(e, stack, context: 'Automatic backup failed'),
        ),
  );
});
