import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Where backups go to and come from. The app uses [FilePickerBackupFileIo];
/// tests pass a fake.
abstract class BackupFileIo {
  /// Offers [contents] to the user as a file called [fileName] (the share sheet
  /// on iOS and Android, a save dialog on desktop, a download on web). Returns
  /// false if cancelled. [origin] is the on-screen box the iPad share popover
  /// points at.
  Future<bool> save({
    required String fileName,
    required String contents,
    Rect? origin,
  });

  /// Lets the user pick a backup file and returns its text, or null if
  /// cancelled.
  Future<String?> pick();
}

/// `file_picker` and `share_plus` implementation. It uses the platform's system
/// dialogs, so no storage permissions are needed.
class FilePickerBackupFileIo implements BackupFileIo {
  const FilePickerBackupFileIo();

  /// The share sheet reaches Files, AirDrop and mail; the save dialog is
  /// clumsy on phones.
  static bool get _useShareSheet =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<bool> save({
    required String fileName,
    required String contents,
    Rect? origin,
  }) async {
    if (_useShareSheet) return _share(fileName, contents, origin);
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: utf8.encode(contents),
      mimeType: 'application/json',
      dialogTitle: 'Save backup',
    );
    return saved != null;
  }

  Future<bool> _share(String fileName, String contents, Rect? origin) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(contents);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        sharePositionOrigin: origin,
      ),
    );
    // `unavailable` means the platform cannot say; assume it went through.
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<String?> pick() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a backup file');
    if (file == null) return null;
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      return '\u0000'; // not text; the codec reports it as invalid
    }
  }
}
