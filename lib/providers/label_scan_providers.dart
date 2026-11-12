import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/label/label_scanner.dart';

export '../data/label/label_scanner.dart' show LabelPhotoSource, LabelScanner;

/// Reads a nutrition label from a photo. A no-op until `main` overrides it
/// on a phone; tests override it with a fake.
final labelScannerProvider = Provider<LabelScanner>(
  (ref) => const NoopLabelScanner(),
);
