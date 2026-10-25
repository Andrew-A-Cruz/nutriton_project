import 'package:nutriton_project/core/widget_snapshot.dart';
import 'package:nutriton_project/data/widget/widget_publisher.dart';

/// A publisher that records every snapshot it is given.
class FakeWidgetPublisher implements WidgetPublisher {
  final List<WidgetSnapshot> published = [];

  WidgetSnapshot get last => published.last;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    published.add(snapshot);
  }
}
