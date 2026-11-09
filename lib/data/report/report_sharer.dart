import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a finished report to the user. The app uses [SystemReportSharer];
/// tests pass a fake.
abstract class ReportSharer {
  /// Offers [bytes] as a PDF called [fileName]: the share sheet on iOS and
  /// Android, a save dialog elsewhere. Returns false if cancelled. [origin]
  /// is the on-screen box the iPad share popover points at.
  Future<bool> share({
    required String fileName,
    required Uint8List bytes,
    Rect? origin,
  });
}

class SystemReportSharer implements ReportSharer {
  const SystemReportSharer();

  @override
  Future<bool> share({
    required String fileName,
    required Uint8List bytes,
    Rect? origin,
  }) async {
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    if (!mobile) {
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: 'Save report',
      );
      return saved != null;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        sharePositionOrigin: origin,
      ),
    );
    // `unavailable` means the platform cannot say; assume it went through.
    return result.status != ShareResultStatus.dismissed;
  }
}
