import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/views/add_food/adhoc_food_form.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// Fiber, sugar and sodium (M13): the optional form fields and the coverage
/// text for totals that only some entries contribute to.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<SharedPreferences> prefsTracking(List<String> tracked) =>
      mockPreferences({
        'onboarding_complete': true,
        'display_unit': 'g',
        'primary_metric': 'calories',
        'goal_calories': 2000.0,
        'tracked_metrics': ['calories', ...tracked],
      });

  Future<void> openRoute(
    WidgetTester tester,
    SharedPreferences prefs,
    WidgetBuilder route,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: RouteHost(route: route),
      ),
    );
    await tester.tap(find.byKey(const Key('open-route')));
    await settle(tester);
  }

  Future<void> fillFood(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('food-name')), 'Oat bar');
    await tester.enterText(find.byKey(const Key('food-calories')), '150');
    await tester.enterText(find.byKey(const Key('food-protein')), '3');
    await tester.enterText(find.byKey(const Key('food-carbs')), '22');
    await tester.enterText(find.byKey(const Key('food-fat')), '5');
    await tester.enterText(find.byKey(const Key('food-serving-weight')), '40');
  }

  group('food form', () {
    testWidgets('shows no extra fields when none are tracked', (tester) async {
      await openRoute(
        tester,
        await prefsTracking([]),
        (_) => const FoodFormView(),
      );

      expect(find.byKey(const Key('food-fiber')), findsNothing);
      expect(find.byKey(const Key('food-sugar')), findsNothing);
      expect(find.byKey(const Key('food-sodium')), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows only the tracked ones, with the right unit', (
      tester,
    ) async {
      await openRoute(
        tester,
        await prefsTracking(['fiber', 'sodium']),
        (_) => const FoodFormView(),
      );

      expect(find.byKey(const Key('food-fiber')), findsOneWidget);
      expect(find.byKey(const Key('food-sugar')), findsNothing);
      expect(find.byKey(const Key('food-sodium')), findsOneWidget);
      expect(find.text('mg'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('empty tracked fields save as null, typed ones as numbers', (
      tester,
    ) async {
      await openRoute(
        tester,
        await prefsTracking(['fiber', 'sugar', 'sodium']),
        (_) => const FoodFormView(),
      );

      await fillFood(tester);
      await tester.enterText(find.byKey(const Key('food-sodium')), '180');
      await tester.enterText(find.byKey(const Key('food-sugar')), '0');
      await tester.tap(find.byKey(const Key('food-save')));
      await settle(tester);

      final food = (await tester.runAsync(
        () => db.foodDao.findActive(),
      ))!.single;
      expect(food.fiber, isNull);
      expect(food.sugar, 0);
      expect(food.sodium, 180);
      await unmount(tester);
    });

    testWidgets('a bad optional value is rejected', (tester) async {
      await openRoute(
        tester,
        await prefsTracking(['sodium']),
        (_) => const FoodFormView(),
      );

      await fillFood(tester);
      await tester.enterText(find.byKey(const Key('food-sodium')), '-3');
      await tester.tap(find.byKey(const Key('food-save')));
      await settle(tester);

      expect(find.text('Cannot be negative'), findsOneWidget);
      expect(await tester.runAsync(() => db.foodDao.findActive()), isEmpty);
      await unmount(tester);
    });

    testWidgets('editing prefills the values, and clearing one stores null', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => CatalogRepository(db).createFood(
          name: 'Oat bar',
          perServing: const Macros(
            calories: 150,
            protein: 3,
            carbs: 22,
            fat: 5,
            fiber: 2.5,
            sodium: 90,
          ),
          servingWeightG: 40,
        ),
      ))!;
      final food = (await tester.runAsync(() => db.foodDao.findById(id)))!;
      await openRoute(
        tester,
        await prefsTracking(['fiber', 'sodium']),
        (_) => FoodFormView(existing: food),
      );

      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(const Key('food-fiber')))
            .controller!
            .text,
        '2.5',
      );
      await tester.enterText(find.byKey(const Key('food-fiber')), '');
      await tester.tap(find.byKey(const Key('food-save')));
      await settle(tester);

      final saved = (await tester.runAsync(() => db.foodDao.findById(id)))!;
      expect(saved.fiber, isNull);
      expect(saved.sodium, 90);
      await unmount(tester);
    });

    testWidgets('a value for an untracked metric is kept when editing', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => CatalogRepository(db).createFood(
          name: 'Oat bar',
          perServing: const Macros(
            calories: 150,
            protein: 3,
            carbs: 22,
            fat: 5,
            sodium: 90,
          ),
          servingWeightG: 40,
        ),
      ))!;
      final food = (await tester.runAsync(() => db.foodDao.findById(id)))!;
      await openRoute(
        tester,
        await prefsTracking([]),
        (_) => FoodFormView(existing: food),
      );

      expect(find.byKey(const Key('food-sodium')), findsNothing);
      await tester.enterText(find.byKey(const Key('food-calories')), '160');
      await tester.tap(find.byKey(const Key('food-save')));
      await settle(tester);

      final saved = (await tester.runAsync(() => db.foodDao.findById(id)))!;
      expect(saved.calories, 160);
      expect(saved.sodium, 90);
      await unmount(tester);
    });
  });

  group('one-off form', () {
    testWidgets('logs the optional fields when tracked', (tester) async {
      await openRoute(
        tester,
        await prefsTracking(['sodium']),
        (_) => CupertinoPageScaffold(child: AdhocFoodForm(logDate: todayKey())),
      );

      expect(find.byKey(const Key('adhoc-fiber')), findsNothing);
      await tester.enterText(find.byKey(const Key('adhoc-name')), 'Burrito');
      await tester.enterText(find.byKey(const Key('adhoc-calories')), '700');
      await tester.enterText(find.byKey(const Key('adhoc-protein')), '30');
      await tester.enterText(find.byKey(const Key('adhoc-carbs')), '80');
      await tester.enterText(find.byKey(const Key('adhoc-fat')), '25');
      await tester.enterText(find.byKey(const Key('adhoc-sodium')), '1450');
      await tester.ensureVisible(find.byKey(const Key('adhoc-log')));
      await tester.tap(find.byKey(const Key('adhoc-log')));
      await settle(tester);

      final entry = (await tester.runAsync(
        () => db.logDao.findEntriesForDate(todayKey()),
      ))!.single;
      expect(entry.sodium, 1450);
      expect(entry.fiber, isNull);
      await unmount(tester);
    });
  });

  group('coverage text', () {
    /// Five entries today; [withSodium] of them record sodium.
    Future<void> seed({required int withSodium}) async {
      final log = LogRepository(db);
      for (var i = 0; i < 5; i++) {
        await log.logAdhoc(
          logDate: todayKey(),
          name: 'Snack $i',
          macros: Macros(
            calories: 100,
            protein: 1,
            carbs: 10,
            fat: 2,
            sodium: i < withSodium ? 200 : null,
          ),
        );
      }
    }

    String sodiumTotal(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('secondary-amount-sodium')))
        .data!;

    testWidgets('Home says how many entries recorded sodium', (tester) async {
      await tester.runAsync(() => seed(withSodium: 3));
      await tester.pumpWidget(
        testApp(db: db, prefs: await prefsTracking(['sodium'])),
      );
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('coverage-sodium'))).data,
        'Sodium recorded for 3 of 5 entries',
      );
      expect(sodiumTotal(tester), '600 mg');
      await unmount(tester);
    });

    testWidgets('Home shows no hint when every entry recorded it', (
      tester,
    ) async {
      await tester.runAsync(() => seed(withSodium: 5));
      await tester.pumpWidget(
        testApp(db: db, prefs: await prefsTracking(['sodium'])),
      );
      await settle(tester);

      expect(find.byKey(const Key('coverage-sodium')), findsNothing);
      expect(sodiumTotal(tester), '1000 mg');
      await unmount(tester);
    });

    testWidgets('Home shows no hint when no entry recorded it', (tester) async {
      await tester.runAsync(() => seed(withSodium: 0));
      await tester.pumpWidget(
        testApp(db: db, prefs: await prefsTracking(['sodium'])),
      );
      await settle(tester);

      expect(find.byKey(const Key('coverage-sodium')), findsNothing);
      expect(sodiumTotal(tester), '0 mg');
      await unmount(tester);
    });

    testWidgets('Summary says it too, and averages per logged day', (
      tester,
    ) async {
      await tester.runAsync(() => seed(withSodium: 3));
      await tester.pumpWidget(
        testApp(db: db, prefs: await prefsTracking(['sodium'])),
      );
      await settle(tester);
      await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('average-sodium'))).data,
        '600 mg',
      );
      expect(find.text('Sodium recorded for 3 of 5 entries'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('settings', () {
    testWidgets('the new nutrients can be tracked, with a goal in mg', (
      tester,
    ) async {
      final prefs = await prefsTracking([]);
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await tester.tap(find.byKey(const Key('settings-button')));
      await settle(tester);

      // Not tracked: no goal row, and they cannot be the primary metric.
      expect(find.byKey(const Key('primary-sodium')), findsNothing);

      await scrollPreferencesTo(tester, find.byKey(const Key('track-sodium')));
      // Stopping at the edge can leave the switch under a bar.
      await tester.ensureVisible(find.byKey(const Key('track-sodium')));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
      await tester.pump();
      await tester.tap(find.byKey(const Key('track-sodium')));
      await tester.pump();
      await scrollPreferencesTo(
        tester,
        find.byKey(const Key('goal-sodium')),
        delta: -200,
      );
      expect(find.text('mg'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('goal-sodium')), '2300');
      await tapSubmitPreferences(tester);
      await settle(tester);

      final saved = prefs.getDouble('goal_sodium');
      expect(saved, 2300);
      expect(prefs.getStringList('tracked_metrics'), contains('sodium'));
      await unmount(tester);
    });
  });
}
