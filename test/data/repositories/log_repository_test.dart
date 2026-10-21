import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/summary_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/summary_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late LogRepository log;
  late SummaryRepository summary;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    log = LogRepository(db);
    summary = SummaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Per 100 g.
  const chickenPer100 = Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6);
  const ricePer100 = Macros(calories: 130, protein: 2.7, carbs: 28, fat: 0.3);

  Future<String> makeChicken() => catalog.createFood(
    name: 'Chicken breast',
    perServing: chickenPer100,
    servingWeightG: 100,
  );

  Future<String> makeRice() => catalog.createFood(
    name: 'White rice',
    perServing: ricePer100,
    servingWeightG: 100,
  );

  group('logFood', () {
    test('snapshots macros and servings for the given date', () async {
      final foodId = await makeChicken();
      final food = (await catalog.findFood(foodId))!;

      final entryId = await log.logFood(
        logDate: '2026-10-20',
        food: food,
        servings: 1.5,
      );

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.logDate, '2026-10-20');
      expect(entry.entryType, 'food');
      expect(entry.calories, closeTo(247.5, 1e-9));
      expect(entry.servings, 1.5);
      expect(entry.foodItemId, foodId);
    });

    test('later catalog edits do not change past entries', () async {
      final foodId = await makeChicken();
      final entryId = await log.logFood(
        logDate: '2026-10-20',
        food: (await catalog.findFood(foodId))!,
        servings: 1,
      );

      await catalog.updateFood(
        foodId,
        name: 'Chicken breast',
        perServing: const Macros(calories: 999, protein: 1, carbs: 1, fat: 1),
        servingWeightG: 100,
      );

      expect((await db.logDao.findEntry(entryId))!.calories, 165);
    });

    test('rejects zero servings', () async {
      final food = (await catalog.findFood(await makeChicken()))!;
      expect(
        () => log.logFood(logDate: '2026-10-20', food: food, servings: 0),
        throwsArgumentError,
      );
    });

    test('rejects non-finite servings when logging or editing', () async {
      final food = (await catalog.findFood(await makeChicken()))!;
      await expectLater(
        log.logFood(
          logDate: '2026-10-20',
          food: food,
          servings: double.infinity,
        ),
        throwsArgumentError,
      );
      await expectLater(
        log.logFood(logDate: '2026-10-20', food: food, servings: double.nan),
        throwsArgumentError,
      );

      final entryId = await log.logFood(
        logDate: '2026-10-20',
        food: food,
        servings: 1,
      );
      await expectLater(
        log.updateServings(entryId, servings: double.infinity),
        throwsArgumentError,
      );
      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.servings, 1);
      expect(entry.calories, 165);
    });

    test('updateServings rescales the snapshot', () async {
      final food = (await catalog.findFood(await makeChicken()))!;
      final entryId = await log.logFood(
        logDate: '2026-10-20',
        food: food,
        servings: 1,
      );

      await log.updateServings(entryId, servings: 2.5);

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.servings, 2.5);
      expect(entry.calories, closeTo(412.5, 1e-9));
      expect(entry.protein, closeTo(77.5, 1e-9));
    });
  });

  group('logMeal', () {
    late String chickenId;
    late String riceId;
    late String mealId;

    setUp(() async {
      chickenId = await makeChicken();
      riceId = await makeRice();
      mealId = await catalog.createMeal(
        name: 'Chicken & rice',
        items: [
          MealItemInput(foodItemId: chickenId, weightG: 150),
          MealItemInput(foodItemId: riceId, weightG: 200),
        ],
      );
    });

    test('writes one entry and a breakdown matching the items', () async {
      final meal = (await catalog.findMeal(mealId))!;
      final entryId = await log.logMeal(
        logDate: '2026-10-20',
        meal: meal,
        items: [
          MealItemInput(foodItemId: chickenId, weightG: 150),
          MealItemInput(foodItemId: riceId, weightG: 200),
        ],
      );

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.entryType, 'meal');
      expect(entry.mealId, mealId);
      expect(entry.servings, isNull);

      // chicken 150 g = 247.5 kcal, rice 200 g = 260 kcal
      expect(entry.calories, closeTo(507.5, 1e-9));

      final items = await db.logDao.findEntryItems(entryId);
      expect(items, hasLength(2));
      expect(items.map((i) => i.weightG), containsAll([150.0, 200.0]));
    });

    test(
      'an adjusted meal logs only the items eaten, leaving the template',
      () async {
        final meal = (await catalog.findMeal(mealId))!;
        final entryId = await log.logMeal(
          logDate: '2026-10-20',
          meal: meal,
          items: [MealItemInput(foodItemId: chickenId, weightG: 100)],
        );

        final entry = (await db.logDao.findEntry(entryId))!;
        expect(entry.calories, closeTo(165, 1e-9));
        expect(await db.logDao.findEntryItems(entryId), hasLength(1));

        final template = await catalog.findMealItems(mealId);
        expect(template.map((i) => i.link.weightG), [150, 200]);
      },
    );

    test(
      'updateTemplate replaces the template in the same transaction',
      () async {
        final meal = (await catalog.findMeal(mealId))!;
        await log.logMeal(
          logDate: '2026-10-20',
          meal: meal,
          items: [MealItemInput(foodItemId: riceId, weightG: 250)],
          updateTemplate: true,
        );

        final template = await catalog.findMealItems(mealId);
        expect(template.map((i) => i.food.id), [riceId]);
        expect(template.single.link.weightG, 250);
      },
    );

    test('a failing item rolls back the whole log', () async {
      final meal = (await catalog.findMeal(mealId))!;
      await expectLater(
        log.logMeal(
          logDate: '2026-10-20',
          meal: meal,
          items: [
            MealItemInput(foodItemId: chickenId, weightG: 100),
            const MealItemInput(foodItemId: 'does-not-exist', weightG: 100),
          ],
          updateTemplate: true,
        ),
        throwsStateError,
      );

      expect(await db.logDao.watchEntriesForDate('2026-10-20').first, isEmpty);
      expect((await catalog.findMealItems(mealId)).map((i) => i.link.weightG), [
        150,
        200,
      ]);
    });

    test('an empty meal log is rejected', () async {
      final meal = (await catalog.findMeal(mealId))!;
      await expectLater(
        log.logMeal(logDate: '2026-10-20', meal: meal, items: const []),
        throwsArgumentError,
      );
    });
  });

  group('logAdhoc', () {
    test('logs without creating a catalog item', () async {
      final entryId = await log.logAdhoc(
        logDate: '2026-10-20',
        name: 'Birthday cake',
        macros: const Macros(calories: 350, protein: 4, carbs: 50, fat: 14),
      );

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.entryType, 'adhoc');
      expect(entry.foodItemId, isNull);
      expect(entry.calories, 350);
      expect(await catalog.findFoods(), isEmpty);
    });

    test('rejects non-finite macros', () async {
      await expectLater(
        log.logAdhoc(
          logDate: '2026-10-20',
          name: 'Bad',
          macros: const Macros(calories: double.infinity),
        ),
        throwsArgumentError,
      );
      await expectLater(
        log.logAdhoc(
          logDate: '2026-10-20',
          name: 'Bad',
          macros: const Macros(fat: double.nan),
        ),
        throwsArgumentError,
      );
      expect(await db.logDao.watchEntriesForDate('2026-10-20').first, isEmpty);
    });
  });

  group('deleteEntry', () {
    test('removes the entry and its breakdown', () async {
      final chickenId = await makeChicken();
      final mealId = await catalog.createMeal(
        name: 'Chicken plate',
        items: [MealItemInput(foodItemId: chickenId, weightG: 100)],
      );
      final entryId = await log.logMeal(
        logDate: '2026-10-20',
        meal: (await catalog.findMeal(mealId))!,
        items: [MealItemInput(foodItemId: chickenId, weightG: 100)],
      );

      await log.deleteEntry(entryId);

      expect(await db.logDao.findEntry(entryId), isNull);
      expect(await db.logDao.findEntryItems(entryId), isEmpty);
    });
  });

  group('SummaryRepository', () {
    test('a week ending on the given day covers exactly 7 days', () async {
      await log.logAdhoc(
        logDate: '2026-10-13', // 7 days before the end: excluded
        name: 'Too early',
        macros: const Macros(calories: 9999),
      );
      await log.logAdhoc(
        logDate: '2026-10-14', // end - 6: included
        name: 'First day',
        macros: const Macros(calories: 1000),
      );
      await log.logAdhoc(
        logDate: '2026-10-20', // end: included
        name: 'Last day',
        macros: const Macros(calories: 2000),
      );

      final report = await summary
          .watchReport(endDate: '2026-10-20', range: SummaryRange.week)
          .first;

      expect(report.startKey, '2026-10-14');
      expect(report.daysLogged, 2);
      expect(report.averages!.calories, closeTo(1500, 1e-9));
    });

    test('the day interval only looks at the end date', () async {
      await log.logAdhoc(
        logDate: '2026-10-19',
        name: 'Yesterday',
        macros: const Macros(calories: 500),
      );
      await log.logAdhoc(
        logDate: '2026-10-20',
        name: 'Today',
        macros: const Macros(calories: 800),
      );

      final report = await summary
          .watchReport(endDate: '2026-10-20', range: SummaryRange.day)
          .first;

      expect(report.averages!.calories, 800);
      expect(report.buckets, isEmpty);
    });
  });
}
