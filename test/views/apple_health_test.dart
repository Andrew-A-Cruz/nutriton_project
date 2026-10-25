import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/health.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/health_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_health_service.dart';
import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeHealthService health;
  final now = DateTime(2026, 10, 21, 8);

  Future<void> logOn(String date, {double calories = 100}) =>
      LogRepository(db).logAdhoc(
        logDate: date,
        name: 'Toast',
        macros: Macros(calories: calories, protein: 3, carbs: 15, fat: 2),
      );

  Future<void> setUpPrefs([Map<String, Object> extra = const {}]) async {
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
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

  Widget app({bool supported = true}) => testApp(
    db: db,
    prefs: prefs,
    overrides: [
      healthServiceProvider.overrideWithValue(health),
      healthSupportedProvider.overrideWithValue(supported),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
  }

  Future<void> scrollToSwitch(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await scrollPreferencesTo(tester, target);
    await tester.ensureVisible(target);
    await tester.pump();
  }

  CupertinoSwitch healthSwitch(WidgetTester tester, String key) =>
      tester.widget<CupertinoSwitch>(find.byKey(Key(key)));

  group('Settings Apple Health', () {
    testWidgets('is off by default and asks for nothing', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 'health-write-switch');
      expect(healthSwitch(tester, 'health-write-switch').value, isFalse);
      expect(healthSwitch(tester, 'health-read-switch').value, isFalse);
      expect(health.authorizations, isEmpty);
      expect(health.writes, isEmpty);
      expect(health.reads, isEmpty);
      await unmount(tester);
    });

    testWidgets('is hidden where there is no health store', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app(supported: false));
      await settle(tester);
      await openSettings(tester);

      await scrollPreferencesToEnd(tester);
      expect(find.text('APPLE HEALTH'), findsNothing);
      expect(find.byKey(const Key('health-write-switch')), findsNothing);
      await unmount(tester);
    });

    testWidgets('writing asks for nutrition access only, then saves', (
      tester,
    ) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 'health-write-switch');
      await tester.tap(find.byKey(const Key('health-write-switch')));
      await settle(tester);

      expect(health.authorizations, [HealthGroup.nutrition]);
      expect(healthSwitch(tester, 'health-write-switch').value, isTrue);
      expect(healthSwitch(tester, 'health-read-switch').value, isFalse);
      expect(prefs.getBool('health_write_nutrition'), isTrue);
      expect(prefs.getBool('health_read_weight'), isFalse);

      // Turning it off asks nothing.
      await tester.tap(find.byKey(const Key('health-write-switch')));
      await settle(tester);
      expect(health.authorizations, hasLength(1));
      expect(prefs.getBool('health_write_nutrition'), isFalse);
      await unmount(tester);
    });

    testWidgets('reading asks for weight access only, then reads', (
      tester,
    ) async {
      health.weights = [(date: '2026-10-20', kg: 80.2)];
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 'health-read-switch');
      await tester.tap(find.byKey(const Key('health-read-switch')));
      await settle(tester);

      expect(health.authorizations, [HealthGroup.weight]);
      expect(healthSwitch(tester, 'health-read-switch').value, isTrue);
      expect(prefs.getBool('health_read_weight'), isTrue);
      expect(health.reads, hasLength(1));
      final stored = await tester.runAsync(
        () => db.select(db.bodyWeights).get(),
      );
      expect(stored!.single.weightKg, 80.2);
      expect(stored.single.source, 'health');
      await unmount(tester);
    });

    testWidgets('a refused permission keeps the switch off', (tester) async {
      health.grant = false;
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 'health-write-switch');
      await tester.tap(find.byKey(const Key('health-write-switch')));
      await settle(tester);

      expect(health.authorizations, [HealthGroup.nutrition]);
      expect(healthSwitch(tester, 'health-write-switch').value, isFalse);
      expect(prefs.getBool('health_write_nutrition'), isNull);
      expect(
        find.textContaining('does not have access to Apple Health'),
        findsOneWidget,
      );
      expect(health.writes, isEmpty);
      await unmount(tester);
    });

    testWidgets('the switches survive Save on the form', (tester) async {
      await setUpPrefs({'health_write_nutrition': true});
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 'health-read-switch');
      await tester.tap(find.byKey(const Key('health-read-switch')));
      await settle(tester);
      await tapSubmitPreferences(tester);
      await settle(tester);

      expect(prefs.getBool('health_write_nutrition'), isTrue);
      expect(prefs.getBool('health_read_weight'), isTrue);
      await unmount(tester);
    });
  });

  group('writing while the app runs', () {
    testWidgets('off: logging makes no health calls', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.runAsync(() => logOn('2026-10-21'));
      await settle(tester);

      expect(health.writes, isEmpty);
      await unmount(tester);
    });

    testWidgets('on: a changed day is rewritten, and only that day', (
      tester,
    ) async {
      await setUpPrefs({'health_write_nutrition': true});
      await tester.runAsync(() => logOn('2026-10-20'));
      await tester.pumpWidget(app());
      await settle(tester);
      // Launch with it already on: a past day is not rewritten.
      expect(health.writes, isEmpty);

      await tester.runAsync(() => logOn('2026-10-21', calories: 250));
      await settle(tester);

      expect(health.writtenDates, ['2026-10-21']);
      expect(health.samplesFor('2026-10-21')!.first, (
        type: HealthNutrient.energy,
        value: 250.0,
        unit: HealthUnit.kilocalorie,
      ));

      health.writes.clear();
      await tester.runAsync(() => logOn('2026-10-20', calories: 50));
      await settle(tester);
      expect(health.writtenDates, ['2026-10-20']);
      await unmount(tester);
    });
  });

  group('Home weigh-in row', () {
    testWidgets('marks a weight that came from Health', (tester) async {
      await setUpPrefs();
      await tester.runAsync(
        () => BodyWeightRepository(
          db,
        ).importHealthReadings([(date: '2026-10-21', kg: 80.2)]),
      );
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('80.2 kg'), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-source')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a typed weight has no hint', (tester) async {
      await setUpPrefs();
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight('2026-10-21', 80.2),
      );
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('80.2 kg'), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-source')), findsNothing);
      await unmount(tester);
    });
  });
}
