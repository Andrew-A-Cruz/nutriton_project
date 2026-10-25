import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';
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

  Future<List<double>> stored() async => [
    for (final r in await db.select(db.bodyWeights).get()) r.weightKg,
  ];

  Future<void> enterAndSave(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('weigh-in-field')), text);
    await tester.tap(find.byKey(const Key('weigh-in-save')));
    await settle(tester);
  }

  group('Home weigh-in row', () {
    testWidgets('shows a prompt, then the saved weight', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      expect(find.text('Weigh in'), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-value')), findsNothing);

      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);
      await enterAndSave(tester, '80.5');

      expect(find.byKey(const Key('weigh-in-field')), findsNothing);
      expect(find.text('80.5 kg'), findsOneWidget);
      expect(await stored(), [80.5]);
      await unmount(tester);
    });

    testWidgets('editing replaces the value and prefills the field', (
      tester,
    ) async {
      final prefs = await prefsWith();
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight(today, 80.5),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      expect(find.text('80.5 kg'), findsOneWidget);
      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);
      final field = tester.widget<CupertinoTextField>(
        find.byKey(const Key('weigh-in-field')),
      );
      expect(field.controller!.text, '80.5');
      await enterAndSave(tester, '79.8');

      expect(find.text('79.8 kg'), findsOneWidget);
      expect(find.text('80.5 kg'), findsNothing);
      expect(await stored(), [79.8]);
      await unmount(tester);
    });

    testWidgets('clear removes the weight', (tester) async {
      final prefs = await prefsWith();
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight(today, 80.5),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('weigh-in-clear')));
      await settle(tester);

      expect(find.text('Weigh in'), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-value')), findsNothing);
      expect(await stored(), isEmpty);
      await unmount(tester);
    });

    testWidgets('there is no clear button when nothing is set', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);

      expect(find.byKey(const Key('weigh-in-clear')), findsNothing);
      await unmount(tester);
    });

    testWidgets('invalid input shows an error and saves nothing', (
      tester,
    ) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);
      for (final bad in ['', 'abc', '0', '-3', '5', '900']) {
        await enterAndSave(tester, bad);
        expect(
          find.byKey(const Key('weigh-in-error')),
          findsOneWidget,
          reason: '"$bad"',
        );
      }
      expect(find.text('Enter a weight between 20 and 500 kg'), findsOneWidget);
      expect(await stored(), isEmpty);
      await unmount(tester);
    });

    testWidgets('lb: shows, edits and stores pounds as kilograms', (
      tester,
    ) async {
      final prefs = await prefsWith({'body_weight_unit': 'lb'});
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight(today, 80),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      expect(find.text('176.4 lb'), findsOneWidget);
      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);
      await enterAndSave(tester, '200');

      expect(find.text('200 lb'), findsOneWidget);
      final kg = (await stored()).single;
      expect(kg, closeTo(90.718474, 1e-6));
      await unmount(tester);
    });

    testWidgets('lb: the bounds are checked in pounds', (tester) async {
      final prefs = await prefsWith({'body_weight_unit': 'lb'});
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('weigh-in-row')));
      await settle(tester);
      await enterAndSave(tester, '30');

      expect(
        find.text('Enter a weight between 44.1 and 1102.3 lb'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('the row follows the selected date', (tester) async {
      final prefs = await prefsWith();
      final yesterday = addDays(today, -1);
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight(yesterday, 81),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      expect(find.text('Weigh in'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.chevron_left).first);
      await settle(tester);

      expect(find.text('81 kg'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Summary weight chart', () {
    Future<void> openSummary(WidgetTester tester) async {
      await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
      await settle(tester);
    }

    testWidgets('shows an empty note when nothing was weighed', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);

      expect(find.byKey(const Key('weight-empty')), findsOneWidget);
      expect(find.byKey(const Key('weight-chart')), findsNothing);
      await unmount(tester);
    });

    testWidgets('draws the chart once there are readings in range', (
      tester,
    ) async {
      final prefs = await prefsWith();
      await tester.runAsync(() async {
        final repo = BodyWeightRepository(db);
        await repo.setWeight(today, 80);
        await repo.setWeight(addDays(today, -2), 81);
        await repo.setWeight(addDays(today, -4), 82);
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);

      expect(find.byKey(const Key('weight-chart')), findsOneWidget);
      expect(find.byKey(const Key('weight-empty')), findsNothing);
      expect(find.textContaining('BODY WEIGHT (kg)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the heading uses the body weight unit', (tester) async {
      final prefs = await prefsWith({'body_weight_unit': 'lb'});
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight(today, 80),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);

      expect(find.textContaining('BODY WEIGHT (lb)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a reading outside the range does not count', (tester) async {
      final prefs = await prefsWith();
      await tester.runAsync(
        () => BodyWeightRepository(db).setWeight(addDays(today, -20), 80),
      );
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);

      // The default range is a week; 20 days back is outside it.
      expect(find.byKey(const Key('weight-empty')), findsOneWidget);

      await tester.tap(find.text('Month'));
      await settle(tester);
      expect(find.byKey(const Key('weight-chart')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the Day range has no weight card', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await openSummary(tester);

      await tester.tap(find.text('Day'));
      await settle(tester);
      expect(find.byKey(const Key('weight-empty')), findsNothing);
      expect(find.byKey(const Key('weight-chart')), findsNothing);
      await unmount(tester);
    });
  });

  group('Settings body weight unit', () {
    testWidgets('defaults to kg and saves the choice', (tester) async {
      final prefs = await prefsWith();
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('settings-button')));
      await settle(tester);
      await scrollPreferencesTo(
        tester,
        find.byKey(const Key('body-weight-unit')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('body-weight-unit')),
          matching: find.text('lb'),
        ),
      );
      await settle(tester);
      await tapSubmitPreferences(tester);
      await settle(tester);

      expect(prefs.getString('body_weight_unit'), 'lb');
      // Food units are untouched.
      expect(prefs.getString('display_unit'), 'g');
      await unmount(tester);
    });

    testWidgets('shows the stored unit', (tester) async {
      final prefs = await prefsWith({'body_weight_unit': 'lb'});
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('settings-button')));
      await settle(tester);
      await scrollPreferencesTo(
        tester,
        find.byKey(const Key('body-weight-unit')),
      );

      final control = tester.widget<CupertinoSlidingSegmentedControl<Object>>(
        find.byKey(const Key('body-weight-unit')),
      );
      expect(control.groupValue.toString(), 'BodyWeightUnit.lb');
      await unmount(tester);
    });
  });
}
