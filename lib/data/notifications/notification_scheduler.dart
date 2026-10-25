/// What the app needs from the operating system's notifications. The real
/// implementation wraps `flutter_local_notifications`
/// (`LocalNotificationScheduler`); tests use a fake.
abstract class NotificationScheduler {
  /// Asks the user for permission to show notifications. Returns whether it
  /// was granted. Call only when the user turns a reminder on.
  Future<bool> requestPermission();

  /// Schedules a one-off notification at local time [when]. An existing one
  /// with the same [id] is replaced.
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  /// Cancels every pending notification.
  Future<void> cancelAll();
}

/// For platforms without notification support, and the default until `main`
/// installs the real one. Permission is never granted.
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}
