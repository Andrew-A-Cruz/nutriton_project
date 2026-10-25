import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';

/// Fiber, sugar and sodium (M13) through the repositories: snapshots copy
/// them, and log again, copy day, undo and edits keep them.
void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late LogRepository log;
  late FoodItem oats;
  late FoodItem plain;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    log = LogRepository(db);
    final oatsId = await catalog.createFood(
      name: 'Oats',
      perServing: const Macros(
        calories: 150,
        protein: 5,
        carbs: 27,
        fat: 3,
        fiber: 4,
        sugar: 1,
        sodium: 100,
      ),
      servingWeightG: 40,
    );
    final plainId = await catalog.createFood(
      name: 'Plain rice',
      perServing: const Macros(calories: 130, protein: 3, carbs: 28, fat: 0.3),
      servingWeightG: 100,
    );
    oats = (await catalog.findFood(oatsId))!;
    plain = (await catalog.findFood(plainId))!;
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<FoodLogEntry>> entries(String date) =>
      db.logDao.findEntriesForDate(date);

  test('logFood scales the recorded values and keeps null as null', () async {
    await log.logFood(logDate: '2026-10-20', food: oats, servings: 1.5);
    await log.logFood(logDate: '2026-10-20', food: plain, servings: 2);

    final byName = {for (final e in await entries('2026-10-20')) e.name: e};
    expect(byName['Oats']!.fiber, 6);
    expect(byName['Oats']!.sugar, 1.5);
    expect(byName['Oats']!.sodium, 150);
    expect(byName['Plain rice']!.fiber, isNull);
    expect(byName['Plain rice']!.sodium, isNull);
  });

  test(
    'logMeal copies per-item values and totals only recorded ones',
    () async {
      final mealId = await catalog.createMeal(
        name: 'Breakfast',
        items: [
          MealItemInput(foodItemId: oats.id, weightG: 80),
          MealItemInput(foodItemId: plain.id, weightG: 100),
        ],
      );
      final meal = (await catalog.findMeal(mealId))!;
      final entryId = await log.logMeal(
        logDate: '2026-10-20',
        meal: meal,
        items: [
          MealItemInput(foodItemId: oats.id, weightG: 80),
          MealItemInput(foodItemId: plain.id, weightG: 100),
        ],
      );

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.fiber, 8);
      expect(entry.sodium, 200);
      final items = {
        for (final i in await db.logDao.findEntryItems(entryId)) i.name: i,
      };
      expect(items['Oats']!.fiber, 8);
      expect(items['Oats']!.sugar, 2);
      expect(items['Plain rice']!.fiber, isNull);
    },
  );

  test('a meal of unrecorded foods has null totals', () async {
    final items = [MealItemInput(foodItemId: plain.id, weightG: 100)];
    final mealId = await catalog.createMeal(name: 'Rice', items: items);
    final entryId = await log.logMeal(
      logDate: '2026-10-20',
      meal: (await catalog.findMeal(mealId))!,
      items: items,
    );
    final entry = (await db.logDao.findEntry(entryId))!;
    expect(entry.sodium, isNull);
  });

  test('updateServings rescales recorded values', () async {
    final id = await log.logFood(
      logDate: '2026-10-20',
      food: oats,
      servings: 1,
    );
    await log.updateServings(id, servings: 3);
    final entry = (await db.logDao.findEntry(id))!;
    expect(entry.sodium, 300);
    expect(entry.fiber, 12);
  });

  test('log again and copy day keep the values', () async {
    final id = await log.logFood(
      logDate: '2026-10-20',
      food: oats,
      servings: 2,
    );
    await log.logFood(logDate: '2026-10-20', food: plain, servings: 1);

    final copyId = await log.duplicateEntry(id, '2026-10-21');
    expect((await db.logDao.findEntry(copyId))!.sodium, 200);

    await log.copyDay(fromDate: '2026-10-20', toDate: '2026-10-22');
    final copies = {for (final e in await entries('2026-10-22')) e.name: e};
    expect(copies['Oats']!.fiber, 8);
    expect(copies['Plain rice']!.fiber, isNull);
  });

  test('a copied meal keeps its breakdown values', () async {
    final items = [
      MealItemInput(foodItemId: oats.id, weightG: 40),
      MealItemInput(foodItemId: plain.id, weightG: 100),
    ];
    final mealId = await catalog.createMeal(name: 'Bowl', items: items);
    final entryId = await log.logMeal(
      logDate: '2026-10-20',
      meal: (await catalog.findMeal(mealId))!,
      items: items,
    );
    final copyId = await log.duplicateEntry(entryId, '2026-10-21');
    final copied = {
      for (final i in await db.logDao.findEntryItems(copyId)) i.name: i,
    };
    expect(copied['Oats']!.sodium, 100);
    expect(copied['Plain rice']!.sodium, isNull);
  });

  test('undo restores the values', () async {
    final id = await log.logFood(
      logDate: '2026-10-20',
      food: oats,
      servings: 1,
    );
    final deleted = (await log.deleteEntryForUndo(id))!;
    await log.restoreEntry(deleted);
    final entry = (await db.logDao.findEntry(id))!;
    expect((entry.fiber, entry.sugar, entry.sodium), (4.0, 1.0, 100.0));
  });

  test('updateAdhoc can set and clear the values', () async {
    final id = await log.logAdhoc(
      logDate: '2026-10-20',
      name: 'Burrito',
      macros: const Macros(calories: 700, sodium: 1400),
    );
    expect((await db.logDao.findEntry(id))!.sodium, 1400);

    await log.updateAdhoc(
      id,
      name: 'Burrito',
      macros: const Macros(calories: 700, fiber: 9),
    );
    final entry = (await db.logDao.findEntry(id))!;
    expect(entry.sodium, isNull);
    expect(entry.fiber, 9);
  });

  test('negative optional values are rejected', () async {
    expect(
      () => log.logAdhoc(
        logDate: '2026-10-20',
        name: 'Bad',
        macros: const Macros(calories: 1, sodium: -1),
      ),
      throwsArgumentError,
    );
  });

  test('daily totals and averages report coverage', () async {
    await log.logFood(logDate: '2026-10-20', food: oats, servings: 1);
    await log.logFood(logDate: '2026-10-20', food: plain, servings: 1);
    await log.logFood(logDate: '2026-10-21', food: plain, servings: 1);

    final days = await db.summaryDao.dailyTotalsForRange(
      '2026-10-20',
      '2026-10-21',
    );
    expect(days, hasLength(2));
    final first = days.first;
    expect(first.totals.sodium, 100);
    expect(first.coverage.values.first.total, 2);
    final sodium = first.coverage.entries
        .firstWhere((e) => e.key.name == 'sodium')
        .value;
    expect((sodium.recorded, sodium.total), (1, 2));
    expect(days.last.totals.sodium, isNull);

    final averages = await db.summaryDao.averagesForRange(
      '2026-10-20',
      '2026-10-21',
    );
    // 100 mg on the first day, none recorded on the second: (100 + 0) / 2.
    expect(averages.averages!.sodium, 50);
  });
}
