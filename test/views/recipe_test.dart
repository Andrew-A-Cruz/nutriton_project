import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String today;
  late String beefId;
  late String beansId;

  setUp(() async {
    today = todayKey();
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// Chili: 500 g beef (250 kcal / 100 g) and 500 g beans (100 kcal / 100 g),
  /// 1,750 kcal raw, cooked down to [cookedG] grams.
  Future<String> seedChili({double? cookedG = 1250}) async {
    final catalog = CatalogRepository(db);
    beefId = await catalog.createFood(
      name: 'Ground beef',
      perServing: const Macros(calories: 250, protein: 26, carbs: 0, fat: 15),
      servingWeightG: 100,
    );
    beansId = await catalog.createFood(
      name: 'Kidney beans',
      perServing: const Macros(calories: 100, protein: 7, carbs: 18, fat: 0.5),
      servingWeightG: 100,
    );
    return catalog.createMeal(
      name: 'Chili',
      items: [
        MealItemInput(foodItemId: beefId, weightG: 500),
        MealItemInput(foodItemId: beansId, weightG: 500),
      ],
      cookedWeightG: cookedG,
    );
  }

  group('repository', () {
    test(
      'a portion scales the entry and its breakdown, not the template',
      () async {
        final mealId = await seedChili();
        final meal = (await db.mealDao.findById(mealId))!;
        final log = LogRepository(db);

        // 250 g of a 1,250 g batch is a fifth.
        final entryId = await log.logMeal(
          logDate: today,
          meal: meal,
          items: [
            MealItemInput(foodItemId: beefId, weightG: 500),
            MealItemInput(foodItemId: beansId, weightG: 500),
          ],
          portion: recipePortion(portionG: 250, cookedWeightG: 1250),
          updateTemplate: true,
        );

        final entry = (await db.logDao.watchEntriesForDate(today).first).single;
        expect(entry.id, entryId);
        expect(entry.calories, closeTo(350, 1e-9));
        expect(entry.protein, closeTo(33, 1e-9));
        final breakdown = await db.logDao.findEntryItems(entryId);
        expect(
          breakdown.map((i) => i.weightG),
          everyElement(closeTo(100, 1e-9)),
        );

        // The template keeps the whole batch and its cooked weight.
        final items = await db.mealDao.findItems(mealId);
        expect(items.map((r) => r.link.weightG), [500, 500]);
        expect((await db.mealDao.findById(mealId))!.cookedWeightG, 1250);
      },
    );

    test('rejects a zero or negative portion', () async {
      final mealId = await seedChili();
      final meal = (await db.mealDao.findById(mealId))!;
      expect(
        () => LogRepository(db).logMeal(
          logDate: today,
          meal: meal,
          items: [MealItemInput(foodItemId: beefId, weightG: 500)],
          portion: 0,
        ),
        throwsArgumentError,
      );
    });

    test('the cooked weight is kept, changed or cleared on update', () async {
      final mealId = await seedChili();
      final catalog = CatalogRepository(db);
      final items = [MealItemInput(foodItemId: beefId, weightG: 500)];

      await catalog.updateMeal(mealId, name: 'Chili', items: items);
      expect((await catalog.findMeal(mealId))!.cookedWeightG, 1250);
      await catalog.updateMeal(
        mealId,
        name: 'Chili',
        items: items,
        cookedWeightG: const Value(900),
      );
      expect((await catalog.findMeal(mealId))!.cookedWeightG, 900);
      await catalog.updateMeal(
        mealId,
        name: 'Chili',
        items: items,
        cookedWeightG: const Value(null),
      );
      expect((await catalog.findMeal(mealId))!.cookedWeightG, isNull);
      expect(
        () => catalog.createMeal(name: 'Soup', items: items, cookedWeightG: 0),
        throwsArgumentError,
      );
    });
  });

  group('screens', () {
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> openMeals(WidgetTester tester) async {
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text('Catalog'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Meals'));
      await settle(tester);
    }

    testWidgets('the meal builder saves a cooked weight', (tester) async {
      tallView(tester);
      final mealId = await tester.runAsync(() => seedChili(cookedG: null));
      await openMeals(tester);
      expect(find.text('2 foods · 1750 kcal'), findsOneWidget);

      await tester.tap(find.text('Chili'));
      await settle(tester);
      await tester.tap(find.text('Edit meal'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('meal-cooked-weight')),
        '1250',
      );
      await tester.tap(find.byKey(const Key('meal-save')));
      await settle(tester);

      final meal = await tester.runAsync(() => db.mealDao.findById(mealId!));
      expect(meal!.cookedWeightG, 1250);
      expect(
        find.text('Recipe · 2 foods · 1750 kcal in 1250 g'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('a bad cooked weight is rejected', (tester) async {
      tallView(tester);
      await tester.runAsync(() => seedChili(cookedG: null));
      await openMeals(tester);
      await tester.tap(find.text('Chili'));
      await settle(tester);
      await tester.tap(find.text('Edit meal'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('meal-cooked-weight')), '0');
      await tester.tap(find.byKey(const Key('meal-save')));
      await settle(tester);
      expect(find.text('Enter a number greater than 0'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a recipe is logged by the portion eaten', (tester) async {
      tallView(tester);
      await tester.runAsync(seedChili);
      await openMeals(tester);
      await tester.tap(find.text('Chili'));
      await settle(tester);
      // Plans log whole templates, so a recipe has no Schedule action.
      expect(find.byKey(const Key('meal-action-schedule')), findsNothing);
      await tester.tap(find.text('Log meal'));
      await settle(tester);

      expect(find.text('WHOLE RECIPE'), findsOneWidget);
      expect(find.byKey(const Key('meal-log-schedule')), findsNothing);
      // The portion is required.
      await tester.tap(find.byKey(const Key('meal-log-confirm')));
      await settle(tester);
      expect(find.text('Enter a number'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('meal-portion')), '250');
      await settle(tester);
      expect(find.text('YOUR PORTION'), findsOneWidget);
      expect(find.text('350 kcal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('meal-log-confirm')));
      await settle(tester);
      final entries = await tester.runAsync(
        () => db.logDao.watchEntriesForDate(today).first,
      );
      expect(entries!.single.name, 'Chili');
      expect(entries.single.calories, closeTo(350, 1e-9));
      await unmount(tester);
    });

    testWidgets('an ordinary meal logs as before, with no portion field', (
      tester,
    ) async {
      tallView(tester);
      await tester.runAsync(() => seedChili(cookedG: null));
      await openMeals(tester);
      await tester.tap(find.text('Chili'));
      await settle(tester);
      await tester.tap(find.text('Log meal'));
      await settle(tester);
      expect(find.byKey(const Key('meal-portion')), findsNothing);
      await tester.tap(find.byKey(const Key('meal-log-confirm')));
      await settle(tester);
      final entries = await tester.runAsync(
        () => db.logDao.watchEntriesForDate(today).first,
      );
      expect(entries!.single.calories, closeTo(1750, 1e-9));
      await unmount(tester);
    });
  });
}
