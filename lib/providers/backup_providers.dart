import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/backup_file_io.dart';
import '../data/repositories/backup_repository.dart';
import 'infrastructure_providers.dart';
import 'preferences_providers.dart';

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
