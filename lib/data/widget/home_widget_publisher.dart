import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/widget_snapshot.dart';
import 'widget_publisher.dart';

/// [WidgetPublisher] over `home_widget`, for the iOS WidgetKit extension in
/// `ios/TodayWidget/`. Not covered by tests, which would need a device.
class HomeWidgetPublisher implements WidgetPublisher {
  HomeWidgetPublisher();

  /// The App Group both the app and the widget extension are members of.
  static const appGroupId = 'group.com.nutriton.app';

  /// The widget's `kind` in `TodayWidget.swift`.
  static const iosWidgetName = 'TodayWidget';

  /// Whether the plugin is used on this platform. Elsewhere use
  /// [NoopWidgetPublisher]. Android has no widget yet.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void>? _init;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    await (_init ??= HomeWidget.setAppGroupId(appGroupId));
    for (final entry in snapshot.toMap().entries) {
      await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
    }
    await HomeWidget.updateWidget(iOSName: iosWidgetName);
  }
}
