import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Where backups go to and come from. The app uses [FilePickerBackupFileIo];
/// tests pass a fake.
abstract class BackupFileIo {
  /// Offers [contents] to the user as a file called [fileName] (a save dialog
  /// on desktop and mobile, a download on web). Returns false if cancelled.
  Future<bool> save({required String fileName, required String contents});

  /// Lets the user pick a backup file and returns its text, or null if
  /// cancelled.
  Future<String?> pick();
}

/// `file_picker` implementation. It uses the platform's system dialogs, so no
/// storage permissions are needed.
class FilePickerBackupFileIo implements BackupFileIo {
  const FilePickerBackupFileIo();

  @override
  Future<bool> save({
    required String fileName,
    required String contents,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: utf8.encode(contents),
      mimeType: 'application/json',
      dialogTitle: 'Save backup',
    );
    return saved != null;
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
