import '../../core/widget_snapshot.dart';
import 'widget_publisher.dart';

/// Sends snapshots to the widget, skipping one identical to the last that was
/// sent. Safe to call as often as wanted.
class WidgetSync {
  WidgetSync(this._publisher);

  final WidgetPublisher _publisher;

  WidgetSnapshot? _last;

  // Calls run one after another, so a slow earlier one cannot overwrite what
  // a later one has just stored.
  Future<void> _tail = Future.value();

  Future<void> sync(WidgetSnapshot snapshot) {
    final run = _tail.then((_) async {
      if (snapshot == _last) return;
      await _publisher.publish(snapshot);
      // Only after success, so a failed publish is retried next time.
      _last = snapshot;
    });
    // A failed run must not block the next one.
    _tail = run.catchError((Object _) {});
    return run;
  }
}
