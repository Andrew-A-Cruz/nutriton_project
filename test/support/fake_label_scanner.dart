import 'package:nutriton_project/core/label_scan.dart';
import 'package:nutriton_project/data/label/label_scanner.dart';

/// A label scanner that returns [lines] (null = the user cancelled) or
/// throws [error], and records which source was asked for.
class FakeLabelScanner implements LabelScanner {
  FakeLabelScanner({this.lines, this.error});

  List<OcrLine>? lines;
  Object? error;
  final List<LabelPhotoSource> asked = [];

  @override
  bool get isSupported => true;

  @override
  Future<List<OcrLine>?> scan(LabelPhotoSource source) async {
    asked.add(source);
    if (error case final e?) throw e;
    return lines;
  }
}
