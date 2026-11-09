import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/number_locale.dart';
import 'data/backup/auto_backup_store.dart';
import 'data/diagnostics/error_log.dart';
import 'data/notifications/local_notification_scheduler.dart';
import 'data/notifications/notification_scheduler.dart';
import 'data/health/health_service.dart';
import 'data/health/plugin_health_service.dart';
import 'providers/backup_providers.dart';
import 'providers/health_providers.dart';
import 'providers/infrastructure_providers.dart';
import 'data/widget/home_widget_publisher.dart';
import 'data/widget/widget_publisher.dart';
import 'providers/reminder_providers.dart';
import 'providers/widget_providers.dart';
import 'data/store/revenuecat_store_service.dart';
import 'data/store/store_service.dart';
import 'providers/entitlement_providers.dart';
import 'providers/review_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  useDecimalSeparatorOf(PlatformDispatcher.instance.locale.toString());
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
        // Phones only: elsewhere there is no Files app to reach the folder.
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android))
          autoBackupStoreProvider.overrideWithValue(DirectoryAutoBackupStore()),
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
        storeServiceProvider.overrideWithValue(
          RevenueCatStoreService.isSupported
              ? RevenueCatStoreService()
              : const NoopStoreService(),
        ),
        // Development builds installed outside the App Store can unlock Pro
        // with --dart-define=PRO_UNLOCKED=true.
        proUnlockedForDevelopmentProvider.overrideWithValue(
          const bool.fromEnvironment('PRO_UNLOCKED'),
        ),
        requestReviewProvider.overrideWithValue(() async {
          final review = InAppReview.instance;
          if (await review.isAvailable()) await review.requestReview();
        }),
      ],
      child: const MyApp(),
    ),
  );
}
