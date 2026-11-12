import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/entitlement_providers.dart';
import 'package:nutriton_project/providers/health_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// Where Pro is not sold (Android until Google Play purchases exist),
/// nothing offers it: no Pro row, no lock badges, no paywall, no trial
/// notice.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<SharedPreferences> prefsWith([Map<String, Object> extra = const {}]) =>
      mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'tracked_metrics': ['calories'],
        'goal_calories': 2000.0,
        ...extra,
      });

  Future<void> pumpApp(
    WidgetTester tester,
    SharedPreferences prefs, {
    bool offered = false,
  }) async {
    // Tall enough to build every Settings section at once.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          proOfferedProvider.overrideWithValue(offered),
          // So the Apple Health section, with its locks, would show.
          healthSupportedProvider.overrideWithValue(true),
        ],
      ),
    );
    await settle(tester);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
  }

  final lock = find.byKey(const Key('pro-lock'));

  testWidgets('Settings has no Pro row, tips, locks or Appearance', (
    tester,
  ) async {
    await pumpApp(tester, await prefsWith());
    await openSettings(tester);

    expect(find.byKey(const Key('pro-row')), findsNothing);
    expect(find.text('LOGBITE PRO'), findsNothing);
    expect(find.text('APPEARANCE'), findsNothing);
    expect(lock, findsNothing);
    // Free sections are all still there.
    expect(find.text('WATER'), findsOneWidget);
    expect(find.text('HELP'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('where Pro is sold, the same screen offers it', (tester) async {
    await pumpApp(tester, await prefsWith(), offered: true);
    await openSettings(tester);

    expect(find.byKey(const Key('pro-row')), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(lock, findsWidgets);
    await unmount(tester);
  });

  testWidgets('Summary has no locked share button', (tester) async {
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: todayKey(),
        name: 'Toast',
        macros: const Macros(calories: 90),
      ),
    );
    await pumpApp(tester, await prefsWith());
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);

    expect(lock, findsNothing);
    expect(find.byKey(const Key('share-report')), findsNothing);
    await unmount(tester);
  });

  testWidgets('an ended trial shows no notice', (tester) async {
    final started = DateTime.now().subtract(const Duration(days: 30));
    await pumpApp(
      tester,
      await prefsWith({'pro_trial_started_at': started.millisecondsSinceEpoch}),
    );
    expect(find.byKey(const Key('trial-ended-notice')), findsNothing);
    await unmount(tester);
  });

  testWidgets('Pro already held still unlocks its features', (tester) async {
    await pumpApp(tester, await prefsWith({'pro_purchased': true}));
    await openSettings(tester);

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.byKey(const Key('theme-green')), findsOneWidget);
    expect(find.byKey(const Key('health-write-switch')), findsOneWidget);
    // Still nothing to buy.
    expect(find.byKey(const Key('pro-row')), findsNothing);
    await unmount(tester);
  });
}
