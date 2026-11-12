import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads and changes the app's home screen icon. A no-op unless `main`
/// replaces it, so tests and unsupported platforms run without it.
abstract interface class AppIconService {
  /// Whether this device can show another icon.
  bool get isSupported;

  /// The alternate icon in use, or null for the primary icon.
  Future<String?> current();

  /// Switches to the alternate icon [name], or back to the primary icon
  /// with null. The system tells the user the icon changed.
  Future<void> set(String? name);
}

class NoopAppIconService implements AppIconService {
  const NoopAppIconService();

  @override
  bool get isSupported => false;

  @override
  Future<String?> current() async => null;

  @override
  Future<void> set(String? name) async {}
}

/// iOS: `UIApplication.setAlternateIconName` through the `logbite/app_icon`
/// channel in `AppDelegate.swift`.
class MethodChannelAppIconService implements AppIconService {
  const MethodChannelAppIconService();

  static const _channel = MethodChannel('logbite/app_icon');

  /// Alternate icons exist on iOS only; Android has no equivalent API.
  static bool get isPlatformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get isSupported => isPlatformSupported;

  @override
  Future<String?> current() => _channel.invokeMethod<String>('get');

  @override
  Future<void> set(String? name) => _channel.invokeMethod<void>('set', name);
}
