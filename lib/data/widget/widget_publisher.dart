import '../../core/widget_snapshot.dart';

/// What the app needs from the home screen widget. The real implementation
/// wraps `home_widget` (`HomeWidgetPublisher`); tests use a fake.
abstract class WidgetPublisher {
  /// Stores [snapshot] where the widget reads it and asks the system to
  /// redraw the widget.
  Future<void> publish(WidgetSnapshot snapshot);
}

/// For platforms without a widget, and the default until `main` installs the
/// real one.
class NoopWidgetPublisher implements WidgetPublisher {
  const NoopWidgetPublisher();

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}
}
