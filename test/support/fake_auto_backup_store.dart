import 'package:nutriton_project/data/backup/auto_backup_store.dart';

/// Keeps automatic backups in memory and counts the writes.
class FakeAutoBackupStore implements AutoBackupStore {
  final Map<String, String> files = {};
  int writes = 0;

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<void> write(String name, String contents) async {
    writes++;
    files[name] = contents;
  }

  @override
  Future<String> read(String name) async =>
      files[name] ?? (throw StateError('No file $name'));

  @override
  Future<void> delete(String name) async => files.remove(name);
}
