import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/water_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late String today;

  setUp(() {
    today = todayKey();
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

  Future<Map<String, double>> stored() async => {
    for (final r in await db.select(db.waterLog).get()) r.logDate: r.amountMl,
  };

  String value(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('water-value'))).data!;

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
  }

  group('Home water row', () {
    testWidgets('plus adds a glass and minus takes one away', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      expect(value(tester), '0 glasses');
      await tap(tester, 'water-plus');
      await tap(tester, 'water-plus');
      await tap(tester, 'water-plus');
      expect(value(tester), '3 glasses');
      expect(await stored(), {today: 750});

      await tap(tester, 'water-minus');
      expect(value(tester), '2 glasses');
      expect(await stored(), {today: 500});
      await unmount(tester);
    });

    testWidgets('minus is off at zero', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      final minus = tester.widget<CupertinoButton>(
        find.byKey(const Key('water-minus')),
      );
      expect(minus.onPressed, isNull);
      await unmount(tester);
    });

    testWidgets('shows the goal, and ml when chosen', (tester) async {
      final prefs = await prefsWith({
        'water_unit': 'ml',
        'water_goal_ml': 2000.0,
      });
      await tester.runAsync(() => WaterRepository(db).add(today, 750));
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      expect(value(tester), '750 of 2000 ml');
      await unmount(tester);
    });

    testWidgets('follows the selected date', (tester) async {
      final prefs = await prefsWith();
      await tester.runAsync(
        () => WaterRepository(db).add(addDays(today, -1), 1000),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      expect(value(tester), '0 glasses');

      await tester.tap(find.byIcon(CupertinoIcons.chevron_left).first);
      await settle(tester);

      expect(value(tester), '4 glasses');
      await tap(tester, 'water-plus');
      expect(await stored(), {addDays(today, -1): 1250});
      await unmount(tester);
    });

    testWidgets('is hidden when water tracking is off', (tester) async {
      final prefs = await prefsWith({'water_enabled': false});
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      expect(find.byKey(const Key('water-row')), findsNothing);
      await unmount(tester);
    });
  });

  group('Settings water section', () {
    testWidgets('the switch hides the row and saves at once', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSettings(tester);
      await scrollPreferencesTo(tester, find.byKey(const Key('water-enabled')));

      await tap(tester, 'water-enabled');

      expect(prefs.getBool('water_enabled'), isFalse);
      expect(find.byKey(const Key('water-goal')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a goal typed in glasses is saved in ml', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSettings(tester);
      await scrollPreferencesTo(tester, find.byKey(const Key('water-goal')));

      await tester.enterText(find.byKey(const Key('water-goal')), '8');
      await settle(tester);
      expect(prefs.getDouble('water_goal_ml'), 2000);

      // Switching to ml keeps the goal and rewrites the field. Typing
      // scrolled the unit control under the navigation bar, so bring it back.
      await tester.drag(
        find.byKey(const Key('water-goal')),
        const Offset(0, 150),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('water-unit')),
          matching: find.text('ml'),
        ),
      );
      await settle(tester);
      expect(prefs.getString('water_unit'), 'ml');
      expect(prefs.getDouble('water_goal_ml'), 2000);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(const Key('water-goal')))
            .controller!
            .text,
        '2000',
      );

      await tester.enterText(find.byKey(const Key('water-goal')), '');
      await settle(tester);
      expect(prefs.getDouble('water_goal_ml'), isNull);
      await unmount(tester);
    });

    testWidgets('a bad goal shows an error and keeps the old one', (
      tester,
    ) async {
      final prefs = await prefsWith({'water_goal_ml': 2000.0});
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSettings(tester);
      await scrollPreferencesTo(tester, find.byKey(const Key('water-goal')));

      await tester.enterText(find.byKey(const Key('water-goal')), 'abc');
      await settle(tester);

      expect(find.text('Enter a number greater than 0'), findsOneWidget);
      expect(prefs.getDouble('water_goal_ml'), 2000);
      await unmount(tester);
    });

    testWidgets('saving the form keeps the water settings', (tester) async {
      final prefs = await prefsWith({
        'water_unit': 'ml',
        'water_goal_ml': 1800.0,
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSettings(tester);
      await tapSubmitPreferences(tester);
      await settle(tester);

      expect(prefs.getString('water_unit'), 'ml');
      expect(prefs.getDouble('water_goal_ml'), 1800);
      await unmount(tester);
    });
  });

  group('Summary water line', () {
    Future<void> openSummary(WidgetTester tester) async {
      await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
      await settle(tester);
    }

    testWidgets('averages the days that have water', (tester) async {
      final prefs = await prefsWith();
      await tester.runAsync(() async {
        final repo = WaterRepository(db);
        await repo.add(today, 1000);
        await repo.add(addDays(today, -2), 2000);
        await repo.add(addDays(today, -20), 5000);
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);

      expect(find.text('Water: 6 glasses a day, over 2 days'), findsOneWidget);

      await tester.tap(find.text('Day'));
      await settle(tester);
      expect(find.text('Water: 4 glasses'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('says nothing with no water, or with tracking off', (
      tester,
    ) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);
      expect(find.byKey(const Key('summary-water')), findsNothing);
      await unmount(tester);
    });
  });
}
