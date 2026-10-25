import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late LogRepository log;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    log = LogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  const macros = Macros(calories: 100, protein: 10, carbs: 10, fat: 1);

  Future<FoodItem> food(String name) async {
    final id = await catalog.createFood(
      name: name,
      perServing: macros,
      servingWeightG: 100,
    );
    return (await catalog.findFood(id))!;
  }

  group('copyDay', () {
    test('copies foods, meals with breakdowns and one-offs', () async {
      final chicken = await food('Chicken');
      final rice = await food('Rice');
      final mealId = await catalog.createMeal(
        name: 'Bowl',
        items: [
          MealItemInput(foodItemId: chicken.id, weightG: 100),
          MealItemInput(foodItemId: rice.id, weightG: 200),
        ],
      );
      await log.logFood(logDate: '2026-10-19', food: chicken, servings: 2);
      await log.logMeal(
        logDate: '2026-10-19',
        meal: (await catalog.findMeal(mealId))!,
        items: [
          MealItemInput(foodItemId: chicken.id, weightG: 100),
          MealItemInput(foodItemId: rice.id, weightG: 150),
        ],
      );
      await log.logAdhoc(logDate: '2026-10-19', name: 'Cake', macros: macros);

      final copied = await log.copyDay(
        fromDate: '2026-10-19',
        toDate: '2026-10-20',
      );

      expect(copied, 3);
      final from = await db.logDao.findEntriesForDate('2026-10-19');
      final to = await db.logDao.findEntriesForDate('2026-10-20');
      expect([for (final e in to) e.name], ['Chicken', 'Bowl', 'Cake']);
      final fromIds = {for (final e in from) e.id};
      expect(to.any((e) => fromIds.contains(e.id)), isFalse);
      expect(to[0].servings, 2);
      expect(to[0].calories, 200);
      expect(to[0].foodItemId, chicken.id);
      expect(to[1].mealId, mealId);
      expect(to[1].calories, closeTo(from[1].calories, 1e-9));

      final items = await db.logDao.findEntryItems(to[1].id);
      expect(items.map((i) => i.weightG).toSet(), {100, 150});
      expect(items.every((i) => i.entryId == to[1].id), isTrue);
      // The source is untouched.
      expect(await db.logDao.findEntryItems(from[1].id), hasLength(2));
    });

    test('uses stored snapshots, not current catalog values', () async {
      final chicken = await food('Chicken');
      await log.logFood(logDate: '2026-10-19', food: chicken, servings: 1);
      await catalog.updateFood(
        chicken.id,
        name: 'Chicken',
        perServing: const Macros(calories: 999, protein: 1, carbs: 1, fat: 1),
        servingWeightG: 100,
      );

      await log.copyDay(fromDate: '2026-10-19', toDate: '2026-10-20');

      final to = await db.logDao.findEntriesForDate('2026-10-20');
      expect(to.single.calories, 100);
    });

    test('keeps existing entries on the target day', () async {
      await log.logAdhoc(logDate: '2026-10-19', name: 'Aa', macros: macros);
      await log.logAdhoc(logDate: '2026-10-20', name: 'Bb', macros: macros);

      await log.copyDay(fromDate: '2026-10-19', toDate: '2026-10-20');

      final to = await db.logDao.findEntriesForDate('2026-10-20');
      expect([for (final e in to) e.name], ['Bb', 'Aa']);
    });

    test('an empty source copies nothing; same day is rejected', () async {
      expect(
        await log.copyDay(fromDate: '2026-10-19', toDate: '2026-10-20'),
        0,
      );
      expect(
        () => log.copyDay(fromDate: '2026-10-19', toDate: '2026-10-19'),
        throwsArgumentError,
      );
    });
  });

  group('duplicateEntry', () {
    test('copies a food entry onto another day', () async {
      final chicken = await food('Chicken');
      final id = await log.logFood(
        logDate: '2026-10-19',
        food: chicken,
        servings: 2,
      );

      final newId = await log.duplicateEntry(id, '2026-10-21');

      expect(newId, isNot(id));
      final copy = (await db.logDao.findEntry(newId))!;
      expect(copy.logDate, '2026-10-21');
      expect(copy.entryType, 'food');
      expect(copy.name, 'Chicken');
      expect(copy.servings, 2);
      expect(copy.calories, 200);
      expect(copy.foodItemId, chicken.id);
      // The source stays where it was.
      final source = (await db.logDao.findEntry(id))!;
      expect(source.logDate, '2026-10-19');
      expect(source.servings, 2);
      expect(await db.logDao.findEntriesForDate('2026-10-19'), hasLength(1));
    });

    test('copies the snapshot, not the current catalog values', () async {
      final chicken = await food('Chicken');
      final id = await log.logFood(
        logDate: '2026-10-19',
        food: chicken,
        servings: 1,
      );
      await catalog.updateFood(
        chicken.id,
        name: 'Chicken',
        perServing: const Macros(calories: 999, protein: 1, carbs: 1, fat: 1),
        servingWeightG: 100,
      );

      final newId = await log.duplicateEntry(id, '2026-10-20');

      expect((await db.logDao.findEntry(newId))!.calories, 100);
    });

    test('copies a meal with its breakdown rows', () async {
      final chicken = await food('Chicken');
      final rice = await food('Rice');
      final mealId = await catalog.createMeal(
        name: 'Bowl',
        items: [
          MealItemInput(foodItemId: chicken.id, weightG: 100),
          MealItemInput(foodItemId: rice.id, weightG: 200),
        ],
      );
      final id = await log.logMeal(
        logDate: '2026-10-19',
        meal: (await catalog.findMeal(mealId))!,
        items: [
          MealItemInput(foodItemId: chicken.id, weightG: 100),
          MealItemInput(foodItemId: rice.id, weightG: 150),
        ],
      );

      final newId = await log.duplicateEntry(id, '2026-10-20');

      final copy = (await db.logDao.findEntry(newId))!;
      final source = (await db.logDao.findEntry(id))!;
      expect(copy.entryType, 'meal');
      expect(copy.mealId, mealId);
      expect(copy.calories, source.calories);
      final copied = await db.logDao.findEntryItems(newId);
      final original = await db.logDao.findEntryItems(id);
      expect(copied, hasLength(2));
      expect(copied.map((i) => i.weightG).toSet(), {100, 150});
      expect(copied.every((i) => i.entryId == newId), isTrue);
      final originalIds = {for (final i in original) i.id};
      expect(copied.any((i) => originalIds.contains(i.id)), isFalse);
      // The source keeps its own rows.
      expect(original, hasLength(2));
    });

    test('copies a one-off entry', () async {
      final id = await log.logAdhoc(
        logDate: '2026-10-19',
        name: 'Cake',
        macros: macros,
      );
      final newId = await log.duplicateEntry(id, '2026-10-20');
      final copy = (await db.logDao.findEntry(newId))!;
      expect(copy.entryType, 'adhoc');
      expect(copy.name, 'Cake');
      expect(copy.calories, 100);
      expect(copy.servings, isNull);
    });

    test('the copy is the newest entry of its day', () async {
      final id = await log.logAdhoc(
        logDate: '2026-10-19',
        name: 'Aa',
        macros: macros,
      );
      await log.logAdhoc(logDate: '2026-10-20', name: 'Bb', macros: macros);
      await log.duplicateEntry(id, '2026-10-20');
      final day = await db.logDao.findEntriesForDate('2026-10-20');
      expect([for (final e in day) e.name], ['Bb', 'Aa']);
    });

    test('can copy onto the same day', () async {
      final id = await log.logAdhoc(
        logDate: '2026-10-19',
        name: 'Cake',
        macros: macros,
      );
      await log.duplicateEntry(id, '2026-10-19');
      expect(await db.logDao.findEntriesForDate('2026-10-19'), hasLength(2));
    });

    test('rejects an unknown entry and a bad date, changing nothing', () async {
      final id = await log.logAdhoc(
        logDate: '2026-10-19',
        name: 'Cake',
        macros: macros,
      );
      await expectLater(
        log.duplicateEntry('missing', '2026-10-20'),
        throwsStateError,
      );
      await expectLater(
        log.duplicateEntry(id, 'tomorrow'),
        throwsFormatException,
      );
      expect(await db.logDao.findEntriesForDate('2026-10-20'), isEmpty);
      expect(await db.logDao.findEntriesForDate('2026-10-19'), hasLength(1));
    });

    test('the copy keeps its macros when the food is archived', () async {
      final chicken = await food('Chicken');
      final id = await log.logFood(
        logDate: '2026-10-19',
        food: chicken,
        servings: 1,
      );
      final newId = await log.duplicateEntry(id, '2026-10-20');
      await catalog.setFoodArchived(chicken.id, archived: true);
      expect((await db.logDao.findEntry(newId))!.calories, 100);
    });
  });

  group('recent and frequent sources', () {
    test('recent lists foods and meals, newest first', () async {
      final chicken = await food('Chicken');
      final mealId = await catalog.createMeal(
        name: 'Bowl',
        items: [MealItemInput(foodItemId: chicken.id, weightG: 100)],
      );
      await log.logFood(logDate: '2026-10-19', food: chicken, servings: 1);
      await log.logMeal(
        logDate: '2026-10-19',
        meal: (await catalog.findMeal(mealId))!,
        items: [MealItemInput(foodItemId: chicken.id, weightG: 100)],
      );
      final names = [
        for (final s in await log.watchRecentSources().first) s.name,
      ];
      expect(names, ['Bowl', 'Chicken']);
    });

    test('frequent honours the start date', () async {
      final chicken = await food('Chicken');
      await log.logFood(logDate: '2026-09-01', food: chicken, servings: 1);
      expect(
        await log.watchFrequentSources(sinceDate: '2026-10-01').first,
        isEmpty,
      );
      expect(
        await log.watchFrequentSources(sinceDate: '2026-09-01').first,
        hasLength(1),
      );
    });

    test('lastServingsFor reads the most recent entry', () async {
      final chicken = await food('Chicken');
      expect(await log.lastServingsFor(chicken.id), isNull);
      await log.logFood(logDate: '2026-10-19', food: chicken, servings: 1);
      await log.logFood(logDate: '2026-10-19', food: chicken, servings: 2.5);
      expect(await log.lastServingsFor(chicken.id), 2.5);
      // Editing the latest entry changes what is remembered.
      final latest = (await db.logDao.findEntriesForDate('2026-10-19')).last;
      await log.updateServings(latest.id, servings: 3);
      expect(await log.lastServingsFor(chicken.id), 3);
    });
  });
}
