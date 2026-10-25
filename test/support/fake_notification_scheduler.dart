import 'package:nutriton_project/data/notifications/notification_scheduler.dart';

/// A scheduler that records what was asked of it. [granted] is the answer to
/// permission requests.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({this.granted = true});

  bool granted;
  int permissionRequests = 0;
  int cancelAllCalls = 0;

  /// Pending notifications by id.
  final Map<int, ({DateTime when, String title, String body})> pending = {};

  /// The pending times, soonest first.
  List<DateTime> get pendingTimes =>
      [for (final p in pending.values) p.when]..sort();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    pending[id] = (when: when, title: title, body: body);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    pending.clear();
  }
}
