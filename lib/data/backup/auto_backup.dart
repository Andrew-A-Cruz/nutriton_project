import '../../core/auto_backup.dart';
import '../preferences/user_preferences.dart';
import '../repositories/backup_repository.dart';
import 'auto_backup_store.dart';

/// Writes an automatic backup when one is due and keeps only the newest
/// [autoBackupsKept].
class AutoBackupRunner {
  AutoBackupRunner({
    required BackupRepository repository,
    required AutoBackupStore store,
    required UserPreferences preferences,
  }) : _repository = repository,
       _store = store,
       _preferences = preferences;

  final BackupRepository _repository;
  final AutoBackupStore _store;
  final UserPreferences _preferences;

  /// The run in progress, so overlapping triggers write one backup.
  Future<bool>? _running;

  /// Writes a backup if automatic backups are on and one is due at [now].
  /// Returns whether one was written.
  Future<bool> runIfDue(DateTime now) =>
      _running ??= _run(now).whenComplete(() => _running = null);

  Future<bool> _run(DateTime now) async {
    if (!_preferences.readAutoBackupEnabled()) return false;
    if (!autoBackupDue(_preferences.readLastAutoBackup(), now)) return false;
    final json = await _repository.exportJson();
    await _store.write(autoBackupFileName(now), json);
    await _preferences.writeLastAutoBackup(now);
    for (final old in autoBackupsToPrune(await _store.list())) {
      await _store.delete(old);
    }
    return true;
  }

  /// The automatic backups on the device, newest first.
  Future<List<String>> list() async =>
      autoBackupsNewestFirst(await _store.list());

  Future<String> read(String name) => _store.read(name);
}
