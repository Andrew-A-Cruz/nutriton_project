import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/health.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/entitlement_providers.dart';
import 'package:nutriton_project/providers/health_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_health_service.dart';
import '../support/test_app.dart';

/// M26: the day's steps from Apple Health on Today and Summary.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeHealthService health;
  final now = DateTime(2026, 10, 21, 8);
  const today = '2026-10-21';

  Future<void> setUpPrefs([Map<String, Object> extra = const {}]) async {
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
      ...extra,
    });
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    health = FakeHealthService();
  });

  tearDown(() async {
    await db.close();
  });

  Widget app({bool pro = true}) => testApp(
    db: db,
    prefs: prefs,
    overrides: [
      healthServiceProvider.overrideWithValue(health),
      healthSupportedProvider.overrideWithValue(true),
      proProvider.overrideWithValue(pro),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> pumpApp(WidgetTester tester, {bool pro = true}) async {
    await tester.pumpWidget(app(pro: pro));
    await settle(tester);
  }

  String stepsText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('steps-value'))).data!;

  group('Today', () {
    testWidgets('no row and no reads while off', (tester) async {
      await setUpPrefs();
      health.steps = {today: 5000};
      await pumpApp(tester);

      expect(find.byKey(const Key('steps-row')), findsNothing);
      expect(health.stepReads, isEmpty);
      await unmount(tester);
    });

    testWidgets('shows the day\'s total', (tester) async {
      await setUpPrefs({UserPreferences.healthShowStepsKey: true});
      health.steps = {today: 8214, '2026-10-20': 99};
      await pumpApp(tester);

      expect(stepsText(tester), '8,214');
      expect(find.byKey(const Key('steps-hint')), findsNothing);
      expect(health.stepReads.last, (start: today, end: today));
      await unmount(tester);
    });

    testWidgets('shows the goal beside the total', (tester) async {
      await setUpPrefs({
        UserPreferences.healthShowStepsKey: true,
        UserPreferences.stepsGoalKey: 10000,
      });
      health.steps = {today: 8214};
      await pumpApp(tester);

      expect(stepsText(tester), '8,214 / 10,000');
      await unmount(tester);
    });

    testWidgets('with no steps, explains access instead of 0', (tester) async {
      await setUpPrefs({UserPreferences.healthShowStepsKey: true});
      await pumpApp(tester);

      expect(stepsText(tester), 'None');
      expect(find.byKey(const Key('steps-hint')), findsOneWidget);
      expect(find.textContaining('Sharing'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hidden without Pro, with the switch kept', (tester) async {
      await setUpPrefs({UserPreferences.healthShowStepsKey: true});
      health.steps = {today: 5000};
      await pumpApp(tester, pro: false);

      expect(find.byKey(const Key('steps-row')), findsNothing);
      expect(health.stepReads, isEmpty);
      expect(prefs.getBool(UserPreferences.healthShowStepsKey), isTrue);
      await unmount(tester);
    });

    testWidgets('reads again when the app returns', (tester) async {
      await setUpPrefs({UserPreferences.healthShowStepsKey: true});
      health.steps = {today: 100};
      await pumpApp(tester);
      expect(stepsText(tester), '100');

      health.steps = {today: 2500};
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);

      expect(stepsText(tester), '2,500');
      await unmount(tester);
    });
  });

  group('Settings', () {
    Future<void> showSwitch(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('settings-button')));
      await settle(tester);
      final target = find.byKey(const Key('health-steps-switch'));
      await scrollPreferencesTo(tester, target);
      await tester.ensureVisible(target);
      await tester.pump();
    }

    testWidgets('turning steps on asks for steps access only', (tester) async {
      await setUpPrefs();
      await pumpApp(tester);
      await showSwitch(tester);
      expect(find.byKey(const Key('steps-goal')), findsNothing);

      await tester.tap(find.byKey(const Key('health-steps-switch')));
      await settle(tester);

      expect(health.authorizations, [HealthGroup.steps]);
      expect(prefs.getBool(UserPreferences.healthShowStepsKey), isTrue);
      // Not part of the backed-up settings.
      expect(prefs.getBool(UserPreferences.healthReadWeightKey), isNot(true));
      expect(find.byKey(const Key('steps-goal')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a refusal keeps the switch off', (tester) async {
      await setUpPrefs();
      health.grant = false;
      await pumpApp(tester);
      await showSwitch(tester);

      await tester.tap(find.byKey(const Key('health-steps-switch')));
      await settle(tester);

      expect(prefs.getBool(UserPreferences.healthShowStepsKey), isNot(true));
      expect(find.textContaining('does not have access'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the goal saves a whole number and clears when blank', (
      tester,
    ) async {
      await setUpPrefs({UserPreferences.healthShowStepsKey: true});
      await pumpApp(tester);
      await showSwitch(tester);
      final field = find.byKey(const Key('steps-goal'));
      await scrollPreferencesTo(tester, field);
      await tester.ensureVisible(field);
      await tester.pump();

      await tester.enterText(field, '7500');
      await tester.pump();
      expect(prefs.getInt(UserPreferences.stepsGoalKey), 7500);

      await tester.enterText(field, '12.5');
      await tester.pump();
      expect(find.textContaining('whole number'), findsOneWidget);
      expect(prefs.getInt(UserPreferences.stepsGoalKey), 7500);

      await tester.enterText(field, '');
      await tester.pump();
      expect(prefs.getInt(UserPreferences.stepsGoalKey), isNull);
      await unmount(tester);
    });
  });

  group('Summary', () {
    testWidgets('shows the average of the days with steps', (tester) async {
      await setUpPrefs({UserPreferences.healthShowStepsKey: true});
      await tester.runAsync(
        () => LogRepository(db).logAdhoc(
          logDate: today,
          name: 'Toast',
          macros: const Macros(calories: 90),
        ),
      );
      health.steps = {today: 9000, '2026-10-20': 7000, '2026-10-19': 0};
      await pumpApp(tester);
      await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
      await settle(tester);
      await tester.tap(find.text('Week'));
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('summary-steps'))).data,
        'Steps: 8,000 a day, over 2 days',
      );
      await unmount(tester);
    });
  });
}
