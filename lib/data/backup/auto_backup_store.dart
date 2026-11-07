import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where automatic backups live. The app uses [DirectoryAutoBackupStore];
/// the default is [NoopAutoBackupStore], so tests and unsupported platforms
/// never touch the file system.
abstract class AutoBackupStore {
  /// The file names in the store.
  Future<List<String>> list();

  Future<void> write(String name, String contents);

  Future<String> read(String name);

  Future<void> delete(String name);
}

/// Stores nothing and lists nothing.
class NoopAutoBackupStore implements AutoBackupStore {
  const NoopAutoBackupStore();

  @override
  Future<List<String>> list() async => const [];

  @override
  Future<void> write(String name, String contents) async {}

  @override
  Future<String> read(String name) =>
      throw StateError('No automatic backup $name');

  @override
  Future<void> delete(String name) async {}
}

/// A "Backups" folder in the app's Documents directory. On iOS the Info.plist
/// keys `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` make it
/// visible in the Files app, so the files can be copied off the phone.
class DirectoryAutoBackupStore implements AutoBackupStore {
  DirectoryAutoBackupStore([Future<Directory> Function()? root])
    : _root = root ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _root;

  Future<Directory> _dir() async {
    final dir = Directory(
      '${(await _root()).path}${Platform.pathSeparator}Backups',
    );
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async {
    if (name.contains('/') || name.contains(r'\')) {
      throw ArgumentError.value(name, 'name', 'must be a plain file name');
    }
    return File('${(await _dir()).path}${Platform.pathSeparator}$name');
  }

  @override
  Future<List<String>> list() async => [
    for (final entity in (await _dir()).listSync())
      if (entity is File) entity.uri.pathSegments.last,
  ];

  @override
  Future<void> write(String name, String contents) async {
    final file = await _file(name);
    // Written beside the target and renamed, so a crash cannot leave half a
    // backup under the real name.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<String> read(String name) async => (await _file(name)).readAsString();

  @override
  Future<void> delete(String name) async {
    final file = await _file(name);
    if (file.existsSync()) await file.delete();
  }
}
