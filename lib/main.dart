import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/notifications/local_notification_scheduler.dart';
import 'data/notifications/notification_scheduler.dart';
import 'data/health/health_service.dart';
import 'data/health/plugin_health_service.dart';
import 'providers/health_providers.dart';
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
        // Apple Health is iOS only; Health Connect on Android is not built.
        healthSupportedProvider.overrideWithValue(
          PluginHealthService.isSupported,
        ),
        healthServiceProvider.overrideWithValue(
          PluginHealthService.isSupported
              ? PluginHealthService()
              : const NoopHealthService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
