import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/appearance.dart';

void main() {
  test('a stored theme reads back; anything else is the standard one', () {
    for (final t in AppTheme.values) {
      expect(AppTheme.fromName(t.name), t);
    }
    expect(AppTheme.fromName(null), AppTheme.standard);
    expect(AppTheme.fromName('neon'), AppTheme.standard);
  });

  test('without Pro the standard theme is used', () {
    expect(effectiveTheme(AppTheme.pink, pro: true), AppTheme.pink);
    expect(effectiveTheme(AppTheme.pink, pro: false), AppTheme.standard);
  });

  test('the standard theme is the system blue', () {
    expect(AppTheme.standard.light, 0xFF007AFF);
    expect(AppTheme.standard.dark, 0xFF0A84FF);
  });

  /// WCAG contrast ratio of an opaque colour against white.
  double contrastOnWhite(int argb) {
    double channel(int v) {
      final c = v / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final l =
        0.2126 * channel((argb >> 16) & 0xFF) +
        0.7152 * channel((argb >> 8) & 0xFF) +
        0.0722 * channel(argb & 0xFF);
    return 1.05 / (l + 0.05);
  }

  test('every light accent is readable as text on white', () {
    for (final t in AppTheme.values) {
      // At least as readable as the system blue (about 4:1).
      expect(contrastOnWhite(t.light), greaterThan(3.9), reason: t.name);
    }
  });

  group('app icons', () {
    test('the system name maps back to the choice', () {
      for (final c in AppIconChoice.values) {
        expect(AppIconChoice.fromIosName(c.iosName), c);
      }
      expect(AppIconChoice.fromIosName('Gone'), AppIconChoice.standard);
      expect(AppIconChoice.standard.iosName, isNull);
    });

    test('every choice has its preview and its Xcode icon set', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      for (final c in AppIconChoice.values) {
        expect(File(c.preview).existsSync(), isTrue, reason: c.preview);
        final name = c.iosName;
        if (name == null) continue;
        expect(
          File(
            'ios/Runner/Assets.xcassets/$name.appiconset/Contents.json',
          ).existsSync(),
          isTrue,
          reason: name,
        );
        // Listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
        expect(project.contains(name), isTrue, reason: name);
      }
    });
  });
}
