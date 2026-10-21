import 'package:drift/drift.dart' show Value;
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

  group('watchRecentFoods', () {
    test('lists each active food once, most recently logged first', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      final c = await food('Cheese');
      final archived = await food('Dates');
      Future<void> at(FoodItem f, DateTime t) => db.logDao.insertEntry(
        FoodLogEntriesCompanion.insert(
          id: '${f.name}-${t.microsecondsSinceEpoch}',
          logDate: '2026-10-20',
          createdAt: t,
          entryType: 'food',
          name: f.name,
          calories: 1,
          protein: 1,
          carbs: 1,
          fat: 1,
          foodItemId: Value(f.id),
          servings: const Value(1),
        ),
      );
      await at(a, DateTime(2026, 10, 1));
      await at(b, DateTime(2026, 10, 3));
      await at(a, DateTime(2026, 10, 5));
      await at(c, DateTime(2026, 10, 2));
      await at(archived, DateTime(2026, 10, 9));
      await catalog.setFoodArchived(archived.id, archived: true);
      // One-off entries never count.
      await log.logAdhoc(logDate: '2026-10-20', name: 'Cake', macros: macros);

      final recent = await log.watchRecentFoods().first;
      expect([for (final f in recent) f.name], ['Apple', 'Bread', 'Cheese']);
    });

    test('respects the limit', () async {
      for (final n in ['Aa', 'Bb', 'Cc']) {
        await log.logFood(
          logDate: '2026-10-20',
          food: await food(n),
          servings: 1,
        );
      }
      expect(await log.watchRecentFoods(limit: 2).first, hasLength(2));
    });
  });
}
