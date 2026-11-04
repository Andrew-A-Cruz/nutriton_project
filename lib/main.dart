import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/diagnostics/error_log.dart';
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
  final errorLog = ErrorLog(prefs);
  // Anything not caught where it happened lands in Settings > Error log.
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    presentError?.call(details);
    unawaited(
      errorLog.record(
        details.exception,
        details.stack,
        context: 'Unexpected error',
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(errorLog.record(error, stack, context: 'Unexpected error'));
    return true;
  };
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        errorLogProvider.overrideWithValue(errorLog),
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
