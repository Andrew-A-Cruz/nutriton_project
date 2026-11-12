import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/label_scan.dart';

/// Where the photo of a nutrition label comes from.
enum LabelPhotoSource { camera, library }

/// Gets a photo of a nutrition label and reads its text on the device. A
/// no-op unless `main` replaces it, so tests and unsupported platforms run
/// without it. Nothing is sent anywhere, and the photo is not kept.
abstract interface class LabelScanner {
  /// Whether this device can read text from a photo.
  bool get isSupported;

  /// Asks for a photo from [source] and returns the text found in it, with
  /// positions. Null when the user cancelled; empty when the photo has no
  /// readable text.
  Future<List<OcrLine>?> scan(LabelPhotoSource source);
}

class NoopLabelScanner implements LabelScanner {
  const NoopLabelScanner();

  @override
  bool get isSupported => false;

  @override
  Future<List<OcrLine>?> scan(LabelPhotoSource source) async => null;
}

/// `image_picker` for the photo, then the `logbite/label_ocr` channel: Apple
/// Vision in `AppDelegate.swift`, ML Kit text recognition in
/// `MainActivity.kt`. Both return lines as the maps [OcrLine.fromMap] reads.
class PlatformLabelScanner implements LabelScanner {
  PlatformLabelScanner({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _channel = MethodChannel('logbite/label_ocr');

  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  bool get isSupported => isPlatformSupported;

  @override
  Future<List<OcrLine>?> scan(LabelPhotoSource source) async {
    final photo = await _picker.pickImage(
      source: switch (source) {
        LabelPhotoSource.camera => ImageSource.camera,
        LabelPhotoSource.library => ImageSource.gallery,
      },
      // Plenty for small print, and quick to read.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    if (photo == null) return null;
    try {
      final lines = await _channel.invokeListMethod<Object?>(
        'recognize',
        photo.path,
      );
      return [
        for (final line in lines ?? const <Object?>[]) ?OcrLine.fromMap(line),
      ];
    } finally {
      // The picker's copy in the app's temporary folder; the label is read,
      // so nothing keeps it.
      try {
        await File(photo.path).delete();
      } on FileSystemException {
        // Already gone, or the system will clear it.
      }
    }
  }
}
