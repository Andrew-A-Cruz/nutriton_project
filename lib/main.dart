import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/notifications/local_notification_scheduler.dart';
import 'data/notifications/notification_scheduler.dart';
import 'providers/infrastructure_providers.dart';
import 'data/widget/home_widget_publisher.dart';
import 'data/widget/widget_publisher.dart';
import 'providers/reminder_providers.dart';
import 'providers/widget_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSchedulerProvider.overrideWithValue(
          LocalNotificationScheduler.isSupported
              ? LocalNotificationScheduler()
              : const NoopNotificationScheduler(),
        ),
        widgetPublisherProvider.overrideWithValue(
          HomeWidgetPublisher.isSupported
              ? HomeWidgetPublisher()
              : const NoopWidgetPublisher(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
